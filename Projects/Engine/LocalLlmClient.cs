using System.Text;
using LLama;
using LLama.Common;
using LLama.Sampling;

namespace SmartInterview
{
    /// <summary>
    /// Fully local, in-process LLM client backed by llama.cpp via LLamaSharp (CUDA/Vulkan/CPU).
    /// Drop-in replacement for the previous Ollama HTTP client: same conversation memory,
    /// same system prompt, same streaming API — but no external server, no network after the
    /// one-time model download, and lower latency (no localhost HTTP round-trip per token).
    /// </summary>
    public sealed class LocalLlmClient : IDisposable
    {
        private sealed record ChatMessage(string Role, string Content);

        // ChatML markers used by Qwen models.
        private const string ImStart = "<|im_start|>";
        private const string ImEnd = "<|im_end|>";

        // Qwen3 hybrid-thinking models reason inside <think>…</think> before answering.
        // Prefilling an EMPTY think block in the assistant turn is the official way to force
        // direct answers when building the prompt manually — no reasoning latency, no leaked
        // chain-of-thought. Pure-instruct models (Qwen3-*-Instruct-2507) must NOT get it.
        private const string NoThinkPrefill = "<think>\n\n</think>\n\n";

        private bool HybridThinking => ModelCatalog.Get(Level).HybridThinking;

        private string AssistantStart() =>
            ImStart + "assistant\n" + (HybridThinking ? NoThinkPrefill : string.Empty);

        private readonly SemaphoreSlim _gate = new(1, 1);
        private readonly List<ChatMessage> _history = new();

        // Conversation window (tokens) the model keeps in context. The full chat history is
        // resent each turn; when it would overflow this we drop the oldest exchanges first.
        private const int DefaultContextSize = 8192;
        private int _contextSize = DefaultContextSize;

        private LLamaWeights? _weights;
        private ModelParams? _params;
        private StatelessExecutor? _executor;
        private int _effectiveGpuLayers;
        private bool _disposed;

        private InterviewProfile _profile = new();
        private AnswerLength _answerLength = AnswerLength.Medium;
        public string LanguageName { get; private set; } = "English";
        public ResponseIntelligence Level { get; private set; } = ResponseIntelligence.Balanced;
        public bool IsLoaded => _executor != null;
        public int LoadedGpuLayerCount => IsLoaded ? _effectiveGpuLayers : 0;
        public bool LoadedOnCpuOnly => IsLoaded && _effectiveGpuLayers == 0;

        /// <summary>Maximum conversation window in tokens (llama.cpp n_ctx).</summary>
        public int ContextSize => _contextSize;

        /// <summary>
        /// Tokens currently used by the conversation (system prompt + full history) the way it
        /// would be sent to the model. 0 until a model is loaded.
        /// </summary>
        public int UsedContextTokens()
        {
            if (_weights == null) return 0;
            string prompt = _history.Count == 0
                ? $"{ImStart}system\n{SystemPrompt()}{ImEnd}\n"
                : BuildChatMlPrompt();
            return CountTokens(prompt);
        }

        /// <summary>
        /// Fixed overhead: system prompt + profile/CV block. This is always present and is
        /// excluded from the conversation fill percentage shown in the UI (starts at 0%).
        /// </summary>
        public int BaselineContextTokens()
        {
            if (_weights == null) return 0;
            return CountTokens($"{ImStart}system\n{SystemPrompt()}{ImEnd}\n");
        }

        /// <summary>Tokens used by Q&amp;A exchanges only (total minus baseline).</summary>
        public int ConversationUsedTokens()
        {
            return Math.Max(0, UsedContextTokens() - BaselineContextTokens());
        }

        /// <summary>Token budget available for conversation after baseline and safety margin.</summary>
        public int ConversationBudgetTokens()
        {
            int baseline = BaselineContextTokens();
            return Math.Max(1, _contextSize - baseline);
        }

        /// <summary>0–100: how full the conversation portion is (baseline = 0%).</summary>
        public int ConversationFillPercent()
        {
            int budget = ConversationBudgetTokens();
            if (budget <= 0) return 0;
            return Math.Min(100, (int)Math.Round(ConversationUsedTokens() * 100.0 / budget));
        }

        private int CountTokens(string text)
        {
            if (string.IsNullOrEmpty(text)) return 0;
            var w = _weights;
            if (w != null)
            {
                try
                {
                    var toks = w.NativeHandle.Tokenize(text, false, true, System.Text.Encoding.UTF8);
                    return toks.Length;
                }
                catch { /* fall back to a rough estimate */ }
            }
            return Math.Max(1, text.Length / 4);
        }

        /// <summary>
        /// Sliding-window trim: drop the oldest user/assistant exchanges (never the system prompt
        /// nor the most recent user turn) until the prompt fits, leaving room for the answer.
        /// </summary>
        // Speed cap on how many recent messages are re-prefilled each turn. StatelessExecutor
        // re-evaluates the whole prompt on every answer, so without a cap the prefill cost keeps
        // growing as the interview goes on and late answers get noticeably slower. Keeping only the
        // most recent exchanges bounds prefill latency (the user's top priority) while still
        // covering immediate follow-ups like "can you elaborate on that?".
        private const int MaxRecentMessages = 12; // ~6 Q&A pairs (excludes the system prompt)

        private void TrimHistoryToBudget(int reserveForAnswer)
        {
            if (_weights == null) return;
            int budget = _contextSize - reserveForAnswer - 256; // safety margin
            if (budget < 512) budget = 512;

            // Hard recency cap first: drop the oldest exchanges (never the system prompt nor the
            // latest user turn) so prefill stays fast regardless of interview length.
            {
                int start = (_history.Count > 0 && _history[0].Role == "system") ? 1 : 0;
                while (_history.Count - start > MaxRecentMessages)
                {
                    _history.RemoveAt(start);
                    if (start < _history.Count && _history[start].Role == "assistant")
                        _history.RemoveAt(start);
                }
            }

            int guard = 0;
            while (CountTokens(BuildChatMlPrompt()) > budget && guard++ < 512)
            {
                int start = (_history.Count > 0 && _history[0].Role == "system") ? 1 : 0;
                if (_history.Count - start <= 1) break; // keep system + latest user
                _history.RemoveAt(start);
                if (start < _history.Count && _history[start].Role == "assistant")
                    _history.RemoveAt(start);
            }
        }

        public string GetLoadStatusText()
        {
            if (!IsLoaded)
                return string.Empty;
            if (LoadedOnCpuOnly)
                return "AI loaded on CPU only - answers will be slower.";
            if (_effectiveGpuLayers == -1)
                return "AI loaded on GPU (all layers).";
            if (_effectiveGpuLayers > 0)
                return $"AI loaded on GPU ({_effectiveGpuLayers} layers).";
            return "AI loaded on GPU (all layers).";
        }

        // ---------- configuration (mirrors the old OllamaClient surface) ----------

        public void SetLanguage(string langName)
        {
            if (langName == LanguageName) return;
            LanguageName = langName;
            RefreshSystemMessage();
        }

        public void SetProfile(InterviewProfile profile)
        {
            _profile = profile ?? new InterviewProfile();
            RefreshSystemMessage();
        }

        public void SetAnswerLength(AnswerLength length)
        {
            if (length == _answerLength) return;
            _answerLength = length;
            RefreshSystemMessage();
        }

        public void Reset() => _history.Clear();

        public void DropLastExchange()
        {
            if (_history.Count > 0 && _history[^1].Role == "assistant") _history.RemoveAt(_history.Count - 1);
            if (_history.Count > 0 && _history[^1].Role == "user") _history.RemoveAt(_history.Count - 1);
        }

        // ---------- model loading ----------

        /// <summary>
        /// Loads the GGUF for the given intelligence level into memory (GPU when possible).
        /// Tries full GPU offload first and falls back to fewer layers / CPU if the device
        /// runs out of memory, so it still works on mid-range or low-VRAM machines.
        /// </summary>
        public async Task LoadAsync(ResponseIntelligence level, CancellationToken ct)
        {
            var path = ModelCatalog.PathFor(level);
            if (!File.Exists(path))
                throw new FileNotFoundException("Local AI model not found. Download it first.", path);

            await _gate.WaitAsync(ct);
            try
            {
                DisposeModel();
                GpuLoadTelemetry.Reset();

                // Try GPU offload first; CPU is a separate last resort.
                int[] gpuLayers = { -1, 99, 80, 60, 40, 20 };
                Exception? last = null;
                foreach (int layers in gpuLayers)
                {
                    try
                    {
                        var mp = new ModelParams(path)
                        {
                            ContextSize = (uint)_contextSize,
                            GpuLayerCount = layers,
                            MainGpu = 0,
                            Threads = Math.Max(1, Environment.ProcessorCount - 1),
                        };
                        var weights = await LLamaWeights.LoadFromFileAsync(mp, ct);
                        _weights = weights;
                        _params = mp;
                        _executor = new StatelessExecutor(weights, mp);
                        Level = level;
                        _effectiveGpuLayers = GpuLoadTelemetry.EffectiveGpuLayerCount(layers);
                        DebugLog.Write($"[LLM] Loaded {level} from {path} requested={layers} effective={_effectiveGpuLayers}");
                        if (_effectiveGpuLayers == 0 && HardwareProbe.GetMaxDedicatedVramBytes() >= 4L * 1024 * 1024 * 1024)
                            DebugLog.Write("[LLM] WARNING: GPU present but model loaded on CPU only.");
                        return;
                    }
                    catch (OperationCanceledException) { throw; }
                    catch (Exception ex)
                    {
                        last = ex;
                        DebugLog.Write($"[LLM] GpuLayerCount={layers} failed: {ex.Message}");
                        DisposeModel();
                    }
                }

                try
                {
                    var mp = new ModelParams(path)
                    {
                        ContextSize = (uint)_contextSize,
                        GpuLayerCount = 0,
                        Threads = Math.Max(1, Environment.ProcessorCount - 1),
                    };
                    var weights = await LLamaWeights.LoadFromFileAsync(mp, ct);
                    _weights = weights;
                    _params = mp;
                    _executor = new StatelessExecutor(weights, mp);
                    Level = level;
                    _effectiveGpuLayers = 0;
                    DebugLog.Write($"[LLM] Loaded {level} from {path} effective=0 (CPU fallback)");
                    return;
                }
                catch (OperationCanceledException) { throw; }
                catch (Exception ex)
                {
                    last = ex;
                    DisposeModel();
                }
                throw new InvalidOperationException(
                    "Could not load the AI model on this machine (out of memory?).", last);
            }
            finally
            {
                _gate.Release();
            }
        }

        /// <summary>
        /// Runs a short generation with the full system prompt so the first real answer
        /// does not pay the entire GPU prefill cost (~seconds on CPU, ~300 ms on Vulkan).
        /// </summary>
        public async Task WarmUpAsync(CancellationToken ct)
        {
            if (_executor == null) return;
            try
            {
                var ip = new InferenceParams
                {
                    MaxTokens = 8,
                    AntiPrompts = new List<string> { ImEnd, ImStart },
                    SamplingPipeline = new DefaultSamplingPipeline { Temperature = 0.35f },
                };
                var prompt = $"{ImStart}system\n{SystemPrompt()}{ImEnd}\n" +
                             $"{ImStart}user\nSay OK.{ImEnd}\n{AssistantStart()}";
                await _gate.WaitAsync(ct);
                try
                {
                    await foreach (var _ in _executor.InferAsync(prompt, ip, ct)) { }
                }
                finally { _gate.Release(); }
                DebugLog.Write("[LLM] WarmUp complete (full system prompt).");
            }
            catch (Exception ex)
            {
                DebugLog.Write($"[LLM] WarmUp skipped: {ex.Message}");
            }
        }

        // ---------- generation ----------

        /// <summary>
        /// Stateless auto-mode gate: should the candidate answer this utterance?
        /// Does not touch interview history. Fails open (answer) on ambiguous output.
        /// </summary>
        public async Task<bool> IsAnswerableUtteranceAsync(string utterance, CancellationToken ct)
        {
            if (_executor == null) return true;
            utterance = utterance.Trim();
            if (utterance.Length == 0) return false;

            string prompt = $"{ImStart}system\n" +
                "You classify short automatic transcripts from a live job interview (technical or HR screening).\n" +
                $"Interview language: {LanguageName}.\n" +
                "Reply with exactly one word: ANSWER or SKIP.\n" +
                "ANSWER: the speaker asks a question, requests information, assigns a task, or raises a topic the candidate must respond to — including very short or informal phrasing, and even without a question mark.\n" +
                "SKIP: only acknowledgement, backchannel, filler, bare greeting, thanks, or reaction with nothing to address (e.g. ok, thanks, I see, interesting, mm-hm).\n" +
                "One word only. No explanation.\n" +
                $"{ImEnd}\n{ImStart}user\n{utterance}{ImEnd}\n{AssistantStart()}";

            var ip = new InferenceParams
            {
                MaxTokens = 6,
                AntiPrompts = new List<string> { ImEnd, ImStart, "\n" },
                SamplingPipeline = new DefaultSamplingPipeline { Temperature = 0f },
            };

            var sb = new StringBuilder();
            await _gate.WaitAsync(ct);
            try
            {
                await foreach (var piece in _executor.InferAsync(prompt, ip, ct))
                    sb.Append(piece);
            }
            finally
            {
                _gate.Release();
            }

            string raw = sb.ToString().Trim().ToUpperInvariant();
            DebugLog.Write($"[CLASSIFY] utterance='{(utterance.Length > 80 ? utterance[..80] + "…" : utterance)}' raw='{raw}'");
            if (raw.Contains("SKIP")) return false;
            return true;
        }

        /// <summary>
        /// Streams the model's answer token by token. The full conversation is rebuilt as a
        /// ChatML prompt each turn (system + history + new question), matching the old client's
        /// behaviour. The completed answer is appended to the history.
        /// </summary>
        public async Task GenerateStreamAsync(string transcription,
            Action<string> onToken, CancellationToken ct)
        {
            if (_executor == null)
                throw new InvalidOperationException("The local AI model is not loaded yet.");

            if (_history.Count == 0)
                _history.Insert(0, new ChatMessage("system", SystemPrompt()));
            else if (_history[0].Role == "system")
                _history[0] = _history[0] with { Content = SystemPrompt() };

            _history.Add(new ChatMessage("user", transcription));

            var (numPredict, _) = AppSettings.GetAnswerLengthOptions(_answerLength);
            TrimHistoryToBudget(numPredict);
            string prompt = BuildChatMlPrompt();

            var ip = new InferenceParams
            {
                MaxTokens = numPredict,
                AntiPrompts = new List<string> { ImEnd, ImStart },
                SamplingPipeline = new DefaultSamplingPipeline
                {
                    // Lower temperature = the model follows the language instruction more closely
                    // and is far less likely to drift into a similar Romance language mid-answer.
                    Temperature = 0.35f,
                    TopP = 0.9f,
                },
            };

            var full = new StringBuilder();
            // Defensive think-block suppression: with the empty-think prefill the model should
            // never reason out loud, but if it still opens a <think> block (sampling noise),
            // swallow everything until </think> instead of showing chain-of-thought to the user.
            bool inThink = false;
            var pending = new StringBuilder(); // holds a potential partial "<think"/"</think" tag
            await _gate.WaitAsync(ct);
            try
            {
                await foreach (var piece in _executor.InferAsync(prompt, ip, ct))
                {
                    if (string.IsNullOrEmpty(piece)) continue;
                    string clean = piece;
                    // Defensive: never leak ChatML control markers into the answer.
                    int cut = clean.IndexOf("<|im", StringComparison.Ordinal);
                    if (cut >= 0) clean = clean.Substring(0, cut);
                    if (clean.Length == 0) continue;

                    pending.Append(clean);
                    string buf = pending.ToString();
                    if (inThink)
                    {
                        int close = buf.IndexOf("</think>", StringComparison.OrdinalIgnoreCase);
                        if (close < 0) { TrimPendingToTagTail(pending); continue; }
                        inThink = false;
                        pending.Clear();
                        pending.Append(buf[(close + "</think>".Length)..].TrimStart());
                        buf = pending.ToString();
                        if (buf.Length == 0) continue;
                    }
                    int open = buf.IndexOf("<think>", StringComparison.OrdinalIgnoreCase);
                    if (open >= 0)
                    {
                        string before = buf[..open];
                        if (before.Length > 0) { full.Append(before); onToken(before); }
                        inThink = true;
                        pending.Clear();
                        pending.Append(buf[(open + "<think>".Length)..]);
                        continue;
                    }
                    // Hold back only a possible partial tag at the end; emit the rest.
                    int hold = PartialTagSuffixLength(buf);
                    string emit = buf[..^hold];
                    if (emit.Length > 0) { full.Append(emit); onToken(emit); }
                    pending.Clear();
                    if (hold > 0) pending.Append(buf[^hold..]);
                }
                // Flush any held-back tail that turned out not to be a tag.
                if (!inThink && pending.Length > 0)
                {
                    string tail = pending.ToString();
                    full.Append(tail);
                    onToken(tail);
                }
            }
            catch
            {
                if (_history.Count > 0 && _history[^1].Role == "user")
                    _history.RemoveAt(_history.Count - 1);
                throw;
            }
            finally
            {
                _gate.Release();
            }

            _history.Add(new ChatMessage("assistant", full.ToString()));
        }

        /// <summary>Length of a suffix of <paramref name="buf"/> that could be the start of
        /// "&lt;think&gt;" or "&lt;/think&gt;" (so it must be held back until more tokens arrive).</summary>
        private static int PartialTagSuffixLength(string buf)
        {
            int max = Math.Min(buf.Length, "</think>".Length - 1);
            for (int len = max; len > 0; len--)
            {
                var tail = buf[^len..];
                if ("<think>".StartsWith(tail, StringComparison.OrdinalIgnoreCase) ||
                    "</think>".StartsWith(tail, StringComparison.OrdinalIgnoreCase))
                    return len;
            }
            return 0;
        }

        /// <summary>While inside a think block only a partial closing tag needs keeping.</summary>
        private static void TrimPendingToTagTail(StringBuilder pending)
        {
            string buf = pending.ToString();
            int hold = PartialTagSuffixLength(buf);
            pending.Clear();
            if (hold > 0) pending.Append(buf[^hold..]);
        }

        private string BuildChatMlPrompt()
        {
            var sb = new StringBuilder();
            foreach (var m in _history)
                sb.Append(ImStart).Append(m.Role).Append('\n').Append(m.Content).Append(ImEnd).Append('\n');
            sb.Append(AssistantStart());
            return sb.ToString();
        }

        // ---------- system prompt (same wording/behaviour as before) ----------

        private void RefreshSystemMessage()
        {
            if (_history.Count > 0 && _history[0].Role == "system")
                _history[0] = _history[0] with { Content = SystemPrompt() };
        }

        private string SystemPrompt()
        {
            string langRule = LanguageName == "Russian"
                ? "- LANGUAGE: write EVERY word in Russian ONLY, using Cyrillic script. NEVER switch to another language. NEVER use CJK, Japanese, Korean, or fullwidth characters."
                : $"- LANGUAGE: write EVERY SINGLE WORD in {LanguageName}. Not one word of any other language — especially NOT Spanish, Portuguese, or English (they look similar to {LanguageName} but are WRONG). If the input was in another language, still answer in {LanguageName}. Do not use non-Latin characters. Re-read your answer mentally and keep it 100% in {LanguageName} from the first word to the last.";

            string langLock = LanguageName == "Russian"
                ? "LANGUAGE LOCK: Your entire answer must be in Russian (Cyrillic) only."
                : $"LANGUAGE LOCK: Your entire answer must be written in {LanguageName} ONLY — every single word, start to finish. Never drift into Spanish, Portuguese, English or any other language, even if the question or earlier turns contain other languages.";

            var (_, lengthHint) = AppSettings.GetAnswerLengthOptions(_answerLength);
            string profileBlock = _profile.ToPromptBlock();

            return $"""
              {langLock}

              You are assisting a candidate during a live, online job interview (technical and/or
              HR screening). Your INPUT is an automatic transcription of audio captured from the
              call, so it may contain noise, filler words, misheard words, broken sentences, or
              chunks of unrelated conversation.

              YOU ARE THE CANDIDATE answering OUT LOUD to the interviewer, right now, in the first
              person. Speak your answer directly, as the words you would actually say.
              CRITICAL — VOICE AND STYLE:
              - Speak in the first person ("I would…", "my approach is…", "in my experience…").
              - Say the answer outright. NEVER describe what you *could* or *would* say. Banned
                openings include: "I could explain…", "I could discuss…", "I could mention…",
                "I might add…", "I could conclude…", "let me tell you about…", and their
                equivalents in any language. Just state the content directly.
              - NEVER apologise and NEVER comment on the input. Do NOT say "I'm sorry", "I apologise
                for the confusion", "there doesn't seem to be a question", "it's not clear what you
                are asking", or anything about whether the text is a question. Never repeat the
                question back, no preambles, no disclaimers, no meta-commentary.
              - Do NOT address the listener with instructions ("you should…"); explain how *you*
                would tackle it.

              DECIDING WHETHER TO ANSWER (do this silently — never mention it):
              - If, and ONLY if, the input contains no question and nothing to address at all
                (pure noise, or just a bare greeting), reply with EXACTLY [[SKIP]] and nothing else.
              - In EVERY other case, ANSWER. If there is ANY question, request, or topic — even
                buried after greetings, rhetorical remarks, or a messy/garbled transcription, even
                if several questions are stacked together — answer the real one (usually the last /
                most relevant) directly. Ignore the surrounding filler.
                Example: "Well, why are you interviewing today? Why do you want to work here?" — this
                IS a question; answer why you want the role. Do NOT skip it and do NOT apologise.
              - When in doubt, ANSWER. Skipping a real interview question is far worse than
                answering a borderline one. Only output [[SKIP]] when you are sure there is nothing
                to answer.
              - Either output [[SKIP]] alone, or give a clean direct answer — never a half-answer
                that questions or apologises for the input.
              - There is NO middle ground: either output [[SKIP]] alone, or give a clean direct
                answer. NEVER produce a half-answer that questions or apologises for the input.
              - Use the previous conversation as context for follow-ups.

              READ THE INTERVIEWER'S INTENT (silently — never name the category out loud). Every
              question is also a test of judgement: identify WHY it is being asked, then answer to
              score the hidden criterion, not just the literal words.
              - TECHNICAL / knowledge questions: answer correctly and concretely, show practical
                experience ("in my last project I…"), mention the key trade-off or pitfall an
                experienced person would know. Depth over buzzwords; never recite a textbook.
              - BEHAVIOURAL questions ("tell me about a time…", "how did you handle…"): tell ONE
                specific story in natural STAR shape — the situation in a sentence, what YOU did,
                and the measurable result — without ever saying "situation/task/action/result".
                Pick stories consistent with the candidate profile below.
              - MOTIVATION / culture-fit ("why this company", "why are you leaving", "where do you
                see yourself"): be positive and specific about what attracts you to THIS role; show
                ambition aligned with the job, never desperation, never "I just need a job".
              - TRICK / STRESS questions — these are tests of composure and self-awareness, do not
                take the bait:
                * "What's your greatest weakness?" → give a REAL but non-disqualifying weakness +
                  the concrete habit you built to manage it. Never "I'm a perfectionist", never a
                  strength in disguise, never a weakness core to the role.
                * "Why are you leaving / what do you dislike about your current job?" → NEVER
                  bad-mouth an employer, manager, or colleague. Frame it as seeking growth.
                * "Why shouldn't we hire you?" / provocative or absurd questions → stay calm and
                  confident, reframe positively, show you can't be rattled.
                * Pressure on gaps, failures, or mistakes → own the mistake briefly, focus on what
                  you learned and changed; no excuses, no blaming others.
                * Leading questions inviting you to criticise a technology, methodology, or person
                  → give a balanced view; absolute trash-talk reads as immaturity.
              - SALARY questions: do not name a number first if avoidable — express flexibility and
                interest in total fit; if pushed, give a reasonable market range for the role and
                say it depends on the overall package.
              - This is SPOKEN language: flowing natural sentences, no bullet lists, no headings,
                no markdown. Sound like a confident human, not a memorised script.

              {lengthHint}
              The length instruction above is mandatory and overrides any instinct to be brief or
              terse: match the requested depth even if the question seems simple.

              {langRule}
              Reply in {LanguageName}.
              {profileBlock}
              """;
        }

        // ---------- lifecycle ----------

        private void DisposeModel()
        {
            _executor = null;
            _weights?.Dispose();
            _weights = null;
            _params = null;
            _effectiveGpuLayers = 0;
        }

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;
            DisposeModel();
            _gate.Dispose();
        }
    }
}
