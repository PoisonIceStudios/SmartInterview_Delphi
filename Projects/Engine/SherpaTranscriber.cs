using SherpaOnnx;

namespace SmartInterview
{
    /// <summary>
    /// NVIDIA Parakeet TDT 0.6B v3 via sherpa-onnx (ONNX Runtime). Transducer architecture:
    /// decodes what was actually said instead of generating text, so it does not invent
    /// "Grazie a tutti" style phrases on noise, and it is roughly an order of magnitude faster
    /// than whisper-large-v3 — int8 decodes a question-length clip in tens of milliseconds on CPU.
    /// Language is auto-detected among 25 European languages (no forcing needed).
    /// Provider: "cpu" by default; SMARTINTERVIEW_SHERPA_PROVIDER=cuda|directml opts into GPU
    /// when a GPU-enabled sherpa-onnx runtime is deployed (falls back to CPU on failure).
    /// </summary>
    public sealed class SherpaTranscriber : IDisposable
    {
        private readonly SemaphoreSlim _gate = new(1, 1);
        private OfflineRecognizer? _recognizer;
        private string _provider = "cpu";
        private bool _disposed;

        public TranscriptionIntelligence Level { get; private set; } = TranscriptionIntelligence.Balanced;

        public string? RuntimeInfo { get; private set; }

        public string? LoadedLibrary => _recognizer != null ? $"sherpa-onnx ({_provider})" : null;

        public bool IsLoaded => _recognizer != null;

        public void Load(TranscriptionIntelligence level)
        {
            Unload();
            var info = SherpaModelCatalog.Get(level);
            var dir = SherpaModelCatalog.DirFor(level);
            if (!SherpaModelCatalog.IsInstalled(level))
                throw new FileNotFoundException("Transcription model not found. Download it first.", dir);

            var requested = (Environment.GetEnvironmentVariable("SMARTINTERVIEW_SHERPA_PROVIDER") ?? "cpu")
                .Trim().ToLowerInvariant();
            if (requested is not ("cpu" or "cuda" or "directml"))
                requested = "cpu";

            try
            {
                _recognizer = CreateRecognizer(info, dir, requested);
                _provider = requested;
            }
            catch when (requested != "cpu")
            {
                DebugLog.Write($"[Parakeet] provider '{requested}' failed, falling back to CPU.");
                _recognizer = CreateRecognizer(info, dir, "cpu");
                _provider = "cpu";
            }

            Level = level;
            RuntimeInfo = $"parakeet-tdt-0.6b-v3 {info.FolderName} provider={_provider}";
            DebugLog.Write($"[Parakeet] loaded {info.FolderName} provider={_provider} dir={dir}");
        }

        private static OfflineRecognizer CreateRecognizer(SherpaModelInfo info, string dir, string provider)
        {
            var config = new OfflineRecognizerConfig();
            config.FeatConfig.SampleRate = 16000;
            config.FeatConfig.FeatureDim = 80;
            config.ModelConfig.Transducer.Encoder = Path.Combine(dir, info.EncoderFile);
            config.ModelConfig.Transducer.Decoder = Path.Combine(dir, info.DecoderFile);
            config.ModelConfig.Transducer.Joiner = Path.Combine(dir, info.JoinerFile);
            config.ModelConfig.Tokens = Path.Combine(dir, "tokens.txt");
            config.ModelConfig.ModelType = "nemo_transducer";
            config.ModelConfig.Provider = provider;
            config.ModelConfig.NumThreads = Math.Clamp(Environment.ProcessorCount - 1, 2, 8);
            config.DecodingMethod = "greedy_search";
            return new OfflineRecognizer(config);
        }

        public void Unload()
        {
            _recognizer?.Dispose();
            _recognizer = null;
            RuntimeInfo = null;
        }

        /// <summary>Parakeet v3 auto-detects the language; nothing to configure.</summary>
        public void SetLanguage(string lang) { }

        /// <summary>Transducers have no initial-prompt conditioning; hint is not needed.</summary>
        public void SetPromptHint(string hint) { }

        /// <summary>Offline transducer decode is near-instant; nothing meaningful to cancel.</summary>
        public void CancelInFlight() { }

        /// <summary>First decode initializes ONNX Runtime kernels; warm up with silence.</summary>
        public async Task WarmUpAsync(CancellationToken ct)
        {
            if (_recognizer == null) return;
            try
            {
                var dummy = new float[16000];
                await TranscribeStreamAsync(dummy, _ => { }, ct, cancelPrevious: false, liveMode: true);
                DebugLog.Write("[Parakeet] warm-up complete.");
            }
            catch (Exception ex)
            {
                DebugLog.Write($"[Parakeet] warm-up skipped: {ex.Message}");
            }
        }

        public async Task<string> TranscribeAsync(float[] samples, CancellationToken ct)
        {
            var sb = new System.Text.StringBuilder();
            await TranscribeStreamAsync(samples, part => sb.Append(part), ct, cancelPrevious: false, liveMode: false);
            return sb.ToString().Trim();
        }

        /// <summary>
        /// Decodes the whole buffer and emits the text as a single part (offline transducer
        /// decoding is fast enough that incremental segments are unnecessary).
        /// </summary>
        // Live-preview gate ONLY. A full utterance (VAD segment end or key release) is decoded at
        // any length ≥0.1s and is accurate even at ~1s (measured 10/10 on real speech). But the
        // live preview feeds growing, half-spoken audio; under ~1.5s Parakeet's auto language
        // detection misfires and invents English ("Psycho", "Yeah"). So we suppress only the
        // PREVIEW below this length — the preview stays blank a moment, then shows correct text;
        // the final transcription is never gated.
        private static readonly int LivePreviewMinSamples =
            int.TryParse(Environment.GetEnvironmentVariable("SMARTINTERVIEW_ASR_MIN_SAMPLES"), out var m) ? m : 24000;

        public async Task TranscribeStreamAsync(float[] samples, Action<string> onPart, CancellationToken ct,
            bool cancelPrevious = false, bool liveMode = false)
        {
            if (samples.Length < 1600) return;
            if (liveMode && samples.Length < LivePreviewMinSamples) return;
            if (_disposed) return;

            Transcriber.PreprocessForAsr(samples);
            if (!liveMode)
                Transcriber.MaybeDumpWav(samples);

            await _gate.WaitAsync(ct);
            try
            {
                if (_disposed) return;
                var recognizer = _recognizer;
                if (recognizer == null) return;

                var text = await Task.Run(() =>
                {
                    using var stream = recognizer.CreateStream();
                    stream.AcceptWaveform(16000, samples);
                    recognizer.Decode(stream);
                    return stream.Result.Text ?? "";
                }, ct);

                text = text.Trim();
                if (text.Length > 0)
                    onPart(text);
            }
            finally
            {
                _gate.Release();
            }
        }

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;
            try { _gate.Wait(5000); } catch { }
            Unload();
            _gate.Dispose();
        }
    }
}
