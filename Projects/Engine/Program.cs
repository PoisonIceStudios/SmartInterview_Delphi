using System.Text.Json;
using System.Text.Json.Serialization;
using SmartInterview;

namespace SmartInterview.Engine;

/// <summary>
/// JSON-lines stdin/stdout engine for the Delphi host. One command per line in, one or more
/// response lines out (generate_stream emits multiple token events).
/// </summary>
internal static class Program
{
    private static readonly Transcriber Transcriber = new();
    private static readonly LocalLlmClient Llm = new();
    private static CancellationTokenSource? _streamCts;
    private static bool _authInitialized;
    private static readonly JsonSerializerOptions JsonOpts = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.SnakeCaseLower,
        DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    };

    private static void LogEngine(string message) =>
        Console.Error.WriteLine($"[SmartInterview.Engine] {message}");

    private static (int Used, int Max, int Baseline, int Pct) ReadContext() =>
        (Llm.UsedContextTokens(), Llm.ContextSize, Llm.BaselineContextTokens(), Llm.ConversationFillPercent());

    private static void ConfigureNativeBackend()
    {
        NativeBackendBootstrap.Configure(LogEngine);
        WhisperBackendBootstrap.Configure(LogEngine);
    }

    private static async Task<int> Main()
    {
        ConfigureNativeBackend();
        LogEngine($"BaseDirectory={AppContext.BaseDirectory}");
        LogEngine($"ModelsDir={AppPaths.ModelsDir}");

        Console.InputEncoding = System.Text.Encoding.UTF8;
        Console.OutputEncoding = System.Text.Encoding.UTF8;

        if (!EngineSessionAuth.TryAuthenticateFromEnvironment(out var authErr))
            LogEngine($"Session auth failed at startup: {authErr ?? "unknown"}");
        else
            LogEngine("Session authenticated from environment.");
        _authInitialized = true;

        string? line;
        while ((line = await Console.In.ReadLineAsync()) != null)
        {
            if (string.IsNullOrWhiteSpace(line)) continue;
            try
            {
                using var doc = JsonDocument.Parse(line);
                var root = doc.RootElement;
                var cmd = root.TryGetProperty("cmd", out var c) ? c.GetString() : null;
                var id = root.TryGetProperty("id", out var i) ? i.GetInt32() : 0;
                await HandleAsync(cmd, id, root);
            }
            catch (Exception ex)
            {
                Write(new { type = "error", id = 0, error = ex.Message });
            }
        }
        return 0;
    }

    private static async Task HandleAsync(string? cmd, int id, JsonElement root)
    {
        if (cmd is not ("shutdown" or null) && _authInitialized && !EngineSessionAuth.IsAuthenticated)
        {
            Reply(id, new { ok = false, error = "unauthorized" });
            return;
        }

        switch (cmd)
        {
            case "ping":
                Reply(id, new { ok = true, version = "1.0" });
                break;

            case "gpu_status":
                Reply(id, new { ok = true, gpu_layers = Llm.LoadedGpuLayerCount, loaded = Llm.IsLoaded });
                break;

            case "startup":
            {
                var sessionToken = root.TryGetProperty("session_token", out var st) ? st.GetString() : null;
                if (!EngineSessionAuth.TryConfirmStartupToken(sessionToken, out var tokenErr))
                {
                    Reply(id, new { ok = false, error = tokenErr ?? "unauthorized" });
                    break;
                }

                var lang = root.TryGetProperty("lang_code", out var lc) ? lc.GetString() ?? "en" : "en";
                var langName = root.TryGetProperty("lang_name", out var ln) ? ln.GetString() ?? "English" : "English";
                var level = root.TryGetProperty("intelligence", out var il) ? (ResponseIntelligence)il.GetInt32() : ResponseIntelligence.Balanced;
                var whisperLevel = root.TryGetProperty("whisper_intelligence", out var wl)
                    ? (TranscriptionIntelligence)wl.GetInt32()
                    : TranscriptionIntelligence.Balanced;
                var len = root.TryGetProperty("length", out var le) ? (AnswerLength)le.GetInt32() : AnswerLength.Medium;
                var profile = new InterviewProfile
                {
                    Role = root.TryGetProperty("role", out var r) ? r.GetString() ?? "" : "",
                    TechStack = root.TryGetProperty("tech_stack", out var t) ? t.GetString() ?? "" : "",
                    JobDescription = root.TryGetProperty("job_description", out var j) ? j.GetString() ?? "" : "",
                    Experience = root.TryGetProperty("experience", out var e) ? e.GetString() ?? "" : "",
                };

                await Transcriber.EnsureModelAsync(whisperLevel, p =>
                    WriteEvent(id, "progress", new { phase = "whisper", progress = p }), CancellationToken.None);
                WriteEvent(id, "progress", new { phase = "voice_init", progress = -1 });
                await Task.Run(() => Transcriber.Load(whisperLevel));
                Transcriber.SetLanguage(lang);
                Llm.SetLanguage(langName ?? "English");
                WriteEvent(id, "progress", new { phase = "voice_init", progress = -1 });
                await Transcriber.WarmUpAsync(CancellationToken.None);

                await ModelDownloader.EnsureModelAsync(level, p =>
                    WriteEvent(id, "progress", new { phase = "llm", progress = p }), CancellationToken.None);
                WriteEvent(id, "progress", new { phase = "text_init", progress = -1 });
                await Llm.LoadAsync(level, CancellationToken.None);
                Llm.SetProfile(profile);
                Llm.SetAnswerLength(len);
                WriteEvent(id, "progress", new { phase = "text_init", progress = -1 });
                await Llm.WarmUpAsync(CancellationToken.None);
                LogEngine($"Startup ready. LLM={level} Whisper={whisperLevel} WhisperLib={Transcriber.LoadedLibrary ?? "?"} WhisperRuntime={Transcriber.RuntimeInfo ?? "?"} GpuLayers={Llm.LoadedGpuLayerCount} CpuOnly={Llm.LoadedOnCpuOnly}");
                Reply(id, new { ok = true, gpu_layers = Llm.LoadedGpuLayerCount });
                break;
            }

            case "ensure_whisper":
            {
                var whisperLevel = root.TryGetProperty("whisper_intelligence", out var wl)
                    ? (TranscriptionIntelligence)wl.GetInt32()
                    : Transcriber.Level;
                await Transcriber.EnsureModelAsync(whisperLevel, p =>
                    WriteEvent(id, "progress", new { phase = "whisper", progress = p }), CancellationToken.None);
                Reply(id, new { ok = true });
                break;
            }

            case "load_whisper":
            {
                var whisperLevel = root.TryGetProperty("whisper_intelligence", out var wl)
                    ? (TranscriptionIntelligence)wl.GetInt32()
                    : Transcriber.Level;
                WriteEvent(id, "progress", new { phase = "voice_init", progress = -1 });
                await Task.Run(() => Transcriber.Load(whisperLevel));
                LogEngine($"Whisper loaded. Lib={Transcriber.LoadedLibrary ?? "?"} Runtime={Transcriber.RuntimeInfo ?? "?"}");
                Reply(id, new { ok = true, whisper_library = Transcriber.LoadedLibrary, whisper_runtime = Transcriber.RuntimeInfo });
                break;
            }

            case "cancel_transcribe":
                Transcriber.CancelInFlight();
                Reply(id, new { ok = true });
                break;

            case "warmup_whisper":
                WriteEvent(id, "progress", new { phase = "voice_warmup", progress = -1 });
                await Transcriber.WarmUpAsync(CancellationToken.None);
                Reply(id, new { ok = true });
                break;

            case "transcribe":
            {
                var b64 = root.GetProperty("samples_b64").GetString() ?? "";
                var bytes = Convert.FromBase64String(b64);
                var samples = new float[bytes.Length / 4];
                Buffer.BlockCopy(bytes, 0, samples, 0, bytes.Length);
                var text = await Transcriber.TranscribeAsync(samples, CancellationToken.None);
                Reply(id, new { ok = true, text });
                break;
            }

            case "transcribe_stream":
            {
                var b64 = root.TryGetProperty("samples_b64", out var sb64) ? sb64.GetString() ?? "" : "";
                var bytes = Convert.FromBase64String(b64);
                var samples = new float[bytes.Length / 4];
                Buffer.BlockCopy(bytes, 0, samples, 0, bytes.Length);
                var live = root.TryGetProperty("live", out var lv) && lv.GetBoolean();
                var sb = new System.Text.StringBuilder();
                try
                {
                    await Transcriber.TranscribeStreamAsync(samples, part =>
                    {
                        sb.Append(part);
                        WriteEvent(id, "transcribe_part", new { text = part, cumulative = sb.ToString() });
                    }, CancellationToken.None, cancelPrevious: live, liveMode: live);
                    Reply(id, new { ok = true, text = sb.ToString().Trim() });
                }
                catch (OperationCanceledException)
                {
                    Reply(id, new { ok = true, cancelled = true, text = sb.ToString().Trim() });
                }
                break;
            }

            case "classify_utterance":
            {
                var text = root.GetProperty("text").GetString() ?? "";
                var answerable = await Llm.IsAnswerableUtteranceAsync(text, CancellationToken.None);
                Reply(id, new { ok = true, answerable });
                break;
            }

            case "set_language":
            {
                var lang = root.GetProperty("lang_code").GetString() ?? "en";
                var langName = root.TryGetProperty("lang_name", out var ln) ? ln.GetString() : "English";
                Transcriber.SetLanguage(lang);
                Llm.SetLanguage(langName ?? "English");
                Reply(id, new { ok = true });
                break;
            }

            case "ensure_model":
            {
                var level = (ResponseIntelligence)root.GetProperty("intelligence").GetInt32();
                await ModelDownloader.EnsureModelAsync(level, p =>
                    WriteEvent(id, "progress", new { phase = "llm", progress = p }), CancellationToken.None);
                Reply(id, new { ok = true });
                break;
            }

            case "load_llm":
            {
                var level = (ResponseIntelligence)root.GetProperty("intelligence").GetInt32();
                await Llm.LoadAsync(level, CancellationToken.None);
                Reply(id, new { ok = true, gpu_layers = Llm.LoadedGpuLayerCount });
                break;
            }

            case "cancel_generation":
                _streamCts?.Cancel();
                Reply(id, new { ok = true, cancelled = true });
                break;

            case "warmup_llm":
                await Llm.WarmUpAsync(CancellationToken.None);
                Reply(id, new { ok = true });
                break;

            case "set_profile":
            {
                var profile = new InterviewProfile
                {
                    Role = root.TryGetProperty("role", out var r) ? r.GetString() ?? "" : "",
                    TechStack = root.TryGetProperty("tech_stack", out var t) ? t.GetString() ?? "" : "",
                    JobDescription = root.TryGetProperty("job_description", out var j) ? j.GetString() ?? "" : "",
                    Experience = root.TryGetProperty("experience", out var e) ? e.GetString() ?? "" : "",
                };
                Llm.SetProfile(profile);
                Reply(id, new { ok = true });
                break;
            }

            case "set_answer_length":
            {
                var len = (AnswerLength)root.GetProperty("length").GetInt32();
                Llm.SetAnswerLength(len);
                Reply(id, new { ok = true });
                break;
            }

            case "reset":
                Llm.Reset();
                var resetCtx = ReadContext();
                Reply(id, new { ok = true, context_used = resetCtx.Used, context_max = resetCtx.Max,
                    context_baseline = resetCtx.Baseline, context_pct = resetCtx.Pct });
                break;

            case "context_status":
                var statusCtx = ReadContext();
                Reply(id, new { ok = true, context_used = statusCtx.Used, context_max = statusCtx.Max,
                    context_baseline = statusCtx.Baseline, context_pct = statusCtx.Pct });
                break;

            case "drop_last_exchange":
                Llm.DropLastExchange();
                Reply(id, new { ok = true });
                break;

            case "generate_stream":
            {
                var question = root.GetProperty("question").GetString() ?? "";
                _streamCts?.Cancel();
                _streamCts?.Dispose();
                _streamCts = new CancellationTokenSource();
                var streamCt = _streamCts.Token;
                try
                {
                    await Llm.GenerateStreamAsync(question, tok =>
                        WriteEvent(id, "token", new { token = tok }), streamCt);
                    var doneCtx = ReadContext();
                    Reply(id, new { ok = true, done = true, context_used = doneCtx.Used, context_max = doneCtx.Max,
                        context_baseline = doneCtx.Baseline, context_pct = doneCtx.Pct });
                }
                catch (OperationCanceledException)
                {
                    Llm.DropLastExchange();
                    var cancelCtx = ReadContext();
                    Reply(id, new { ok = true, cancelled = true, context_used = cancelCtx.Used, context_max = cancelCtx.Max,
                        context_baseline = cancelCtx.Baseline, context_pct = cancelCtx.Pct });
                }
                break;
            }

            case "shutdown":
                Reply(id, new { ok = true });
                Environment.Exit(0);
                break;

            default:
                Reply(id, new { ok = false, error = $"unknown cmd: {cmd}" });
                break;
        }
    }

    private static void Reply(int id, object payload)
    {
        var dict = JsonSerializer.SerializeToElement(payload, JsonOpts);
        using var ms = new MemoryStream();
        using (var writer = new Utf8JsonWriter(ms))
        {
            writer.WriteStartObject();
            writer.WriteNumber("id", id);
            writer.WriteString("type", "result");
            foreach (var prop in dict.EnumerateObject())
                prop.WriteTo(writer);
            writer.WriteEndObject();
        }
        var json = System.Text.Encoding.UTF8.GetString(ms.ToArray());
        Console.Out.WriteLine(json);
        Console.Out.Flush();
    }

    private static void WriteEvent(int id, string type, object data)
    {
        var dict = JsonSerializer.SerializeToElement(data, JsonOpts);
        using var ms = new MemoryStream();
        using (var writer = new Utf8JsonWriter(ms))
        {
            writer.WriteStartObject();
            writer.WriteNumber("id", id);
            writer.WriteString("type", type);
            foreach (var prop in dict.EnumerateObject())
                prop.WriteTo(writer);
            writer.WriteEndObject();
        }
        var json = System.Text.Encoding.UTF8.GetString(ms.ToArray());
        Console.Out.WriteLine(json);
        Console.Out.Flush();
    }

    private static void Write(object obj)
    {
        Console.Out.WriteLine(JsonSerializer.Serialize(obj, JsonOpts));
        Console.Out.Flush();
    }
}
