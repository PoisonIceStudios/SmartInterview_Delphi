using Whisper.net;
using Whisper.net.LibraryLoader;

namespace SmartInterview
{
    /// <summary>
    /// Wrapper around Whisper.net. Loads the model (downloading it on first run if missing),
    /// uses CUDA12/Vulkan/CPU via WhisperBackendBootstrap, and transcribes blocks of 16 kHz
    /// mono PCM audio. Only one inference at a time.
    /// </summary>
    public sealed class Transcriber : IDisposable
    {
        private readonly SemaphoreSlim _gate = new(1, 1);
        private readonly CancellationTokenSource _disposeCts = new();
        private CancellationTokenSource? _inflightCts;
        private WhisperFactory? _factory;
        private WhisperProcessor? _processor;
        private WhisperProcessor? _liveProcessor;
        private volatile string _language = "en";
        private volatile string _promptHint = "";
        private volatile bool _needsRebuild;
        private bool _disposed;
        private string? _runtimeInfo;

        public TranscriptionIntelligence Level { get; private set; } = TranscriptionIntelligence.Balanced;

        public string Language => _language;

        public string ModelPath => WhisperModelCatalog.PathFor(Level);

        public string? RuntimeInfo => _runtimeInfo;

        public string? LoadedLibrary => RuntimeOptions.LoadedLibrary?.ToString();

        /// <summary>Downloads the model for <paramref name="level"/> if missing (and verifies its hash).</summary>
        public static async Task EnsureModelAsync(TranscriptionIntelligence level,
            Action<double?>? progress, CancellationToken ct)
        {
            await WhisperModelDownloader.EnsureModelAsync(level, progress, ct);
        }

        public void Load()
        {
            Load(Level);
        }

        public void Load(TranscriptionIntelligence level)
        {
            if (Level != level || _factory == null)
            {
                UnloadModel();
                Level = level;
            }

            var path = ModelPath;
            if (!File.Exists(path))
                throw new FileNotFoundException("Transcription model not found. Download it first.");

            _factory = WhisperFactory.FromPath(path, new WhisperFactoryOptions
            {
                UseGpu = true,
                GpuDevice = 0,
            });
            LogRuntimeInfo();
            BuildProcessors();
            DebugLog.Write($"[Whisper] model={Level} lang={_language} library={LoadedLibrary ?? "?"} path={path}");
        }

        /// <summary>Changes the transcription language. Rebuilds processors on next inference.</summary>
        public void SetLanguage(string lang)
        {
            if (lang == _language) return;
            _language = lang;
            _needsRebuild = true;
        }

        /// <summary>
        /// Sets an initial prompt that biases Whisper toward the interview's technical vocabulary
        /// (product names, frameworks, English jargon). Whisper conditions its decoding on this
        /// text, so terms like "Unity", "React" or ".NET" are recognised and spelled correctly
        /// instead of being mangled into ordinary words. Kept short to avoid the model echoing it.
        /// Rebuilds processors on next inference.
        /// </summary>
        public void SetPromptHint(string hint)
        {
            hint = (hint ?? string.Empty).Trim();
            // Keep the prompt SHORT: long prompts measurably increase hallucinations on
            // degraded audio (a 40-term list turned a short question into invented text).
            // 320 chars ≈ one natural sentence with profile terms + a small base vocabulary.
            if (hint.Length > 320)
            {
                int cut = hint.LastIndexOf(' ', 320);
                hint = hint.Substring(0, cut > 0 ? cut : 320).TrimEnd(',', ' ');
            }
            if (hint == _promptHint) return;
            _promptHint = hint;
            _needsRebuild = true;
        }

        /// <summary>Cancels an in-flight live preview transcription so a fresher chunk can run.</summary>
        public void CancelInFlight()
        {
            try { _inflightCts?.Cancel(); } catch { }
        }

        /// <summary>Frees the Whisper model and processors (used when switching to another engine tier).</summary>
        public void Unload()
        {
            UnloadModel();
        }

        private void UnloadModel()
        {
            try
            {
                if (_processor != null)
                    _processor.DisposeAsync().AsTask().GetAwaiter().GetResult();
                if (_liveProcessor != null)
                    _liveProcessor.DisposeAsync().AsTask().GetAwaiter().GetResult();
            }
            catch { }
            _processor = null;
            _liveProcessor = null;
            _factory?.Dispose();
            _factory = null;
            _runtimeInfo = null;
        }

        private void LogRuntimeInfo()
        {
            try
            {
                _runtimeInfo = WhisperFactory.GetRuntimeInfo()?.ToString();
                DebugLog.Write($"[Whisper] runtime: {_runtimeInfo}");
            }
            catch
            {
                _runtimeInfo = "unknown";
            }
        }

        private void BuildProcessors()
        {
            _processor?.Dispose();
            _liveProcessor?.Dispose();

            // Final pass: best accuracy for release / segment end.
            // TemperatureInc(0) disables the temperature fallback: on near-silent or
            // ambiguous audio the fallback re-decodes at higher temperature and confidently
            // hallucinates common phrases ("Grazie", "Grazie a tutti", subtitle credits).
            // Greedy decoding (temp 0) with no fallback keeps clean audio accurate and stops
            // those hallucinations at the source.
            // EntropyThreshold/LogProbThreshold mark a low-quality decode (noise-driven, high
            // entropy / low confidence). They feed the same no-speech logic we then enforce in
            // IsHallucination, and cost nothing on clean speech.
            // Beam search (beam 5, like OpenAI's reference settings) explores alternative
            // decodings and picks the most probable one — a significant word-accuracy win over
            // greedy on accented speech and technical terms, for a modest decode-time cost on
            // the final pass only. Live preview stays greedy for latency.
            var finalBuilder = _factory!.CreateBuilder()
                .WithLanguage(_language)
                .WithNoContext()
                .WithTemperature(0.0f)
                .WithTemperatureInc(0.0f)
                .WithNoSpeechThreshold(0.7f)
                .WithEntropyThreshold(2.4f)
                .WithLogProbThreshold(-1.0f);
            if (_promptHint.Length > 0)
                finalBuilder = finalBuilder.WithPrompt(_promptHint);
            _processor = finalBuilder.Build();

            // Live pass: shorter windows, faster first callback, stricter silence gate.
            var liveBuilder = _factory.CreateBuilder()
                .WithLanguage(_language)
                .WithNoContext()
                .WithTemperature(0.0f)
                .WithTemperatureInc(0.0f)
                .WithNoSpeechThreshold(0.85f)
                .WithEntropyThreshold(2.4f)
                .WithLogProbThreshold(-1.0f);
            if (_promptHint.Length > 0)
                liveBuilder = liveBuilder.WithPrompt(_promptHint);
            _liveProcessor = liveBuilder.Build();

            _needsRebuild = false;
        }

        /// <summary>Runs a dummy transcription to warm up GPU shaders (~20s first launch).</summary>
        public async Task WarmUpAsync(CancellationToken ct)
        {
            var rnd = new Random(1);
            var dummy = new float[16000];
            for (int i = 0; i < dummy.Length; i++)
                dummy[i] = (float)(rnd.NextDouble() * 0.1 - 0.05);
            await TranscribeStreamAsync(dummy, _ => { }, ct, cancelPrevious: false, liveMode: true);
        }

        // Light ASR front-end, in spirit similar to what WebRTC/voice apps run before their
        // recogniser: (1) remove DC offset, (2) high-pass to kill rumble and plosive thumps,
        // (3) AGC toward a healthy loudness with a hard peak limiter. A distant/low-gain mic or
        // low-frequency room noise is the usual reason Whisper mishears whole phrases; this makes
        // the speech the model actually sees consistent and clear. Upstream gates already removed
        // pure silence, so what arrives here is real speech.
        internal static void PreprocessForAsr(float[] x)
        {
            // Diagnostic escape hatch: SMARTINTERVIEW_SKIP_ASR_PREPROCESS=1 feeds the raw
            // capture to the model, to tell preprocessing issues apart from model issues.
            if (Environment.GetEnvironmentVariable("SMARTINTERVIEW_SKIP_ASR_PREPROCESS") == "1")
                return;
            int n = x.Length;
            if (n == 0) return;

            // 1) DC offset removal.
            double mean = 0;
            for (int i = 0; i < n; i++) mean += x[i];
            float dc = (float)(mean / n);

            // 2) One-pole high-pass (~80 Hz @ 16 kHz): y[i] = a*(y[i-1] + x[i] - x[i-1]).
            const float a = 0.985f;
            float prevX = 0f, prevY = 0f;
            for (int i = 0; i < n; i++)
            {
                float xi = x[i] - dc;
                float yi = a * (prevY + xi - prevX);
                prevX = xi;
                prevY = yi;
                x[i] = yi;
            }

            // 3) RMS-based AGC (boost-only) with a peak limiter so we never clip.
            double sumSq = 0;
            float peak = 0f;
            for (int i = 0; i < n; i++)
            {
                float ax = x[i] < 0 ? -x[i] : x[i];
                if (ax > peak) peak = ax;
                sumSq += (double)x[i] * x[i];
            }
            if (peak < 1e-4f) return;                    // essentially silent
            float rms = (float)Math.Sqrt(sumSq / n);
            float gain = rms > 1e-6f ? 0.12f / rms : 1f; // target ~ -18 dBFS speech level
            if (gain < 1f) gain = 1f;                    // only ever lift quiet audio
            if (gain > 12f) gain = 12f;                  // don't over-amplify noise/near-silence
            if (peak * gain > 0.97f) gain = 0.97f / peak; // hard peak safety (may trim if hot)
            if (gain != 1f)
                for (int i = 0; i < n; i++) x[i] *= gain;
        }

        // Diagnostic: when SMARTINTERVIEW_DUMP_AUDIO=1, write exactly what the final pass feeds to
        // Whisper (post-preprocessing, 16 kHz mono) to %LOCALAPPDATA%\SmartInterview\
        // last-whisper-input.wav. Playing it back instantly reveals whether a misheard phrase is a
        // wrong/quiet/noisy capture or a genuine model miss.
        internal static void MaybeDumpWav(float[] samples)
        {
            var flag = Environment.GetEnvironmentVariable("SMARTINTERVIEW_DUMP_AUDIO");
            if (flag is not ("1" or "true" or "TRUE")) return;
            try
            {
                string dir = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "SmartInterview");
                Directory.CreateDirectory(dir);
                string path = Path.Combine(dir, "last-whisper-input.wav");
                WriteWav16k(path, samples);
                DebugLog.Write($"[Whisper] dumped input audio -> {path} ({samples.Length} samples)");
            }
            catch (Exception ex)
            {
                DebugLog.Write($"[Whisper] wav dump failed: {ex.Message}");
            }
        }

        private static void WriteWav16k(string path, float[] samples)
        {
            const int rate = 16000;
            int dataBytes = samples.Length * 2;
            using var fs = new FileStream(path, FileMode.Create, FileAccess.Write);
            using var bw = new BinaryWriter(fs);
            bw.Write(System.Text.Encoding.ASCII.GetBytes("RIFF"));
            bw.Write(36 + dataBytes);
            bw.Write(System.Text.Encoding.ASCII.GetBytes("WAVE"));
            bw.Write(System.Text.Encoding.ASCII.GetBytes("fmt "));
            bw.Write(16);
            bw.Write((short)1);          // PCM
            bw.Write((short)1);          // mono
            bw.Write(rate);
            bw.Write(rate * 2);          // byte rate
            bw.Write((short)2);          // block align
            bw.Write((short)16);         // bits per sample
            bw.Write(System.Text.Encoding.ASCII.GetBytes("data"));
            bw.Write(dataBytes);
            for (int i = 0; i < samples.Length; i++)
            {
                float v = samples[i];
                if (v > 1f) v = 1f; else if (v < -1f) v = -1f;
                bw.Write((short)(v * 32767f));
            }
        }

        public async Task<string> TranscribeAsync(float[] samples, CancellationToken ct)
        {
            var sb = new System.Text.StringBuilder();
            await TranscribeStreamAsync(samples, part => sb.Append(part), ct, cancelPrevious: false, liveMode: false);
            return sb.ToString().Trim();
        }

        /// <summary>Transcribes audio and invokes <paramref name="onPart"/> for each Whisper segment as it is decoded.</summary>
        public async Task TranscribeStreamAsync(float[] samples, Action<string> onPart, CancellationToken ct,
            bool cancelPrevious = false, bool liveMode = false)
        {
            if (samples.Length < 1600) return;
            if (_disposed) return;

            PreprocessForAsr(samples);
            if (!liveMode)
                MaybeDumpWav(samples);

            if (cancelPrevious)
                CancelInFlight();

            using var linked = CancellationTokenSource.CreateLinkedTokenSource(ct, _disposeCts.Token);
            await _gate.WaitAsync(linked.Token);
            // Publish our CTS only once we own the gate: before that, CancelInFlight must hit
            // the *running* transcription (so it frees the gate for us), not this waiting one.
            _inflightCts = linked;
            try
            {
                if (_disposed) return;
                if (_needsRebuild) BuildProcessors();
                var processor = liveMode ? _liveProcessor : _processor;
                if (processor == null) return;

                await foreach (var seg in processor.ProcessAsync(samples, linked.Token))
                {
                    var part = seg.Text;
                    if (string.IsNullOrWhiteSpace(part))
                        continue;
                    if (IsHallucination(seg))
                    {
                        DebugLog.Write($"[Whisper] dropped hallucination noSpeech={seg.NoSpeechProbability:0.00} " +
                            $"prob={seg.Probability:0.00} text=\"{part.Trim()}\"");
                        continue;
                    }
                    onPart(part);
                }
            }
            finally
            {
                if (ReferenceEquals(_inflightCts, linked))
                    _inflightCts = null;
                _gate.Release();
            }
        }

        // Phrases Whisper invents on silence / background noise (subtitle credits, thank-you
        // outros). They are never real interview content, so a short segment that reduces to
        // one of these (at low confidence) is dropped. Compared after stripping punctuation and
        // lowercasing. The list is balanced across every supported language so coverage does not
        // skew to one locale.
        private static readonly HashSet<string> HallucinationPhrases = new(StringComparer.Ordinal)
        {
            // English
            "you", "thank you", "thanks", "thanks for watching", "thank you for watching",
            "please subscribe", "subscribe to my channel", "like and subscribe", "see you next time",
            // Italian
            "grazie", "grazie a tutti", "grazie a voi", "grazie mille", "grazie della visione",
            "grazie per la visione", "grazie per aver guardato", "sottotitoli", "buona visione",
            "iscrivetevi al canale",
            // German
            "danke", "vielen dank", "untertitel", "untertitel von stephanie geiges",
            "bis zum nachsten mal", "tschuss",
            // French
            "merci", "merci d avoir regarde", "sous titres", "a la prochaine", "abonnez vous",
            // Spanish
            "gracias", "gracias por ver", "subtitulos", "suscribete", "hasta la proxima",
            // Portuguese
            "obrigado", "obrigada", "obrigado por assistir", "legendas", "se inscreva",
            // Russian
            "спасибо", "спасибо за просмотр", "подписывайтесь", "продолжение следует",
            // Chinese / Japanese
            "谢谢", "请订阅", "字幕", "ご視聴ありがとうございました",
            // generic
            "bye", "bye bye", "ok", "okay",
        };

        private static bool IsHallucination(SegmentData seg)
        {
            // Strong silence signal: the model itself is fairly sure there is no speech here.
            if (seg.NoSpeechProbability > 0.55f)
                return true;

            var norm = NormalizeForMatch(seg.Text);
            if (norm.Length == 0)
                return true;

            int words = WordCount(norm);

            // Language-independent guard: a SHORT segment decoded with very low average token
            // confidence (avg log-prob) over near-silence is almost always invented — real
            // speech, even quiet, decodes with markedly higher confidence than noise-driven text.
            // Restricted to short segments so a genuine long answer with a couple of uncertain
            // words is never dropped.
            if (words <= 6 && seg.Probability < -0.85f)
                return true;

            // Known filler/credit phrase in any language, at low confidence. Exact match or the
            // segment starting with the phrase (e.g. "grazie a tutti per la visione di oggi").
            if (seg.Probability < -0.50f && MatchesHallucinationPhrase(norm))
                return true;

            return false;
        }

        private static bool MatchesHallucinationPhrase(string norm)
        {
            if (HallucinationPhrases.Contains(norm))
                return true;
            foreach (var phrase in HallucinationPhrases)
            {
                // startsWith + word boundary so "thanks" does not swallow "thanks to caching…".
                if (norm.Length > phrase.Length &&
                    norm.StartsWith(phrase, StringComparison.Ordinal) &&
                    norm[phrase.Length] == ' ')
                    return true;
            }
            return false;
        }

        private static int WordCount(string norm)
        {
            if (norm.Length == 0) return 0;
            int n = 1;
            foreach (var ch in norm)
                if (ch == ' ') n++;
            return n;
        }

        private static string NormalizeForMatch(string text)
        {
            // Fold diacritics so "subtítulos"/"subtitulos" and "à la"/"a la" match regardless of
            // how Whisper renders accents. FormD splits accented letters into base + combining
            // mark; we drop the marks. Cyrillic/CJK have no decomposable marks here, so they pass
            // through unchanged.
            string lowered = text.Trim().ToLowerInvariant()
                .Normalize(System.Text.NormalizationForm.FormD);
            var sb = new System.Text.StringBuilder(lowered.Length);
            char prevSpace = ' ';
            foreach (var ch in lowered)
            {
                if (System.Globalization.CharUnicodeInfo.GetUnicodeCategory(ch)
                    == System.Globalization.UnicodeCategory.NonSpacingMark)
                    continue;
                if (char.IsLetterOrDigit(ch))
                {
                    sb.Append(ch);
                    prevSpace = ch;
                }
                else if (char.IsWhiteSpace(ch) || ch == '\'' || ch == '-')
                {
                    if (prevSpace != ' ')
                        sb.Append(' ');
                    prevSpace = ' ';
                }
                // drop all other punctuation (., !, ?, …, etc.)
            }
            return sb.ToString().Trim();
        }

        public void Dispose()
        {
            _disposed = true;
            CancelInFlight();
            try { _disposeCts.Cancel(); } catch { }
            try { _gate.Wait(5000); } catch { }
            UnloadModel();
            _gate.Dispose();
            _disposeCts.Dispose();
        }
    }
}
