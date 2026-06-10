namespace SmartInterview
{
    /// <summary>
    /// Routes transcription to the engine behind the selected tier:
    ///   Fast / Balanced -> Parakeet TDT 0.6B v3 (sherpa-onnx) — faster, noise-robust, 25 languages;
    ///   Max             -> Whisper large-v3 (Whisper.net)     — alternative engine for comparison
    ///                       and for very noisy audio.
    /// Exposes the exact surface Program.cs used with the Whisper Transcriber, so the IPC
    /// protocol and the Delphi side are unchanged. Switching tiers unloads the other engine
    /// to free RAM/VRAM.
    /// </summary>
    public sealed class HybridTranscriber : IDisposable
    {
        private readonly Transcriber _whisper = new();
        private readonly SherpaTranscriber _parakeet = new();
        private string _language = "en";
        private string _promptHint = "";
        private bool _disposed;

        public TranscriptionIntelligence Level { get; private set; } = TranscriptionIntelligence.Balanced;

        private bool UseParakeet(TranscriptionIntelligence level) => SherpaModelCatalog.IsParakeetLevel(level);

        private bool ActiveIsParakeet => UseParakeet(Level);

        public string? RuntimeInfo => ActiveIsParakeet ? _parakeet.RuntimeInfo : _whisper.RuntimeInfo;

        public string? LoadedLibrary => ActiveIsParakeet ? _parakeet.LoadedLibrary : _whisper.LoadedLibrary;

        public Task EnsureModelAsync(TranscriptionIntelligence level,
            Action<double?>? progress, CancellationToken ct)
        {
            return UseParakeet(level)
                ? SherpaModelDownloader.EnsureModelAsync(level, progress, ct)
                : Transcriber.EnsureModelAsync(level, progress, ct);
        }

        public void Load(TranscriptionIntelligence level)
        {
            if (UseParakeet(level))
            {
                _whisper.Unload();
                _parakeet.Load(level);
            }
            else
            {
                _parakeet.Unload();
                _whisper.Load(level);
                _whisper.SetLanguage(_language);
                _whisper.SetPromptHint(_promptHint);
            }
            Level = level;
        }

        public void SetLanguage(string lang)
        {
            _language = lang;
            _whisper.SetLanguage(lang);   // Whisper needs forcing; Parakeet auto-detects
            _parakeet.SetLanguage(lang);
        }

        public void SetPromptHint(string hint)
        {
            _promptHint = hint;
            _whisper.SetPromptHint(hint); // vocabulary biasing only applies to Whisper
            _parakeet.SetPromptHint(hint);
        }

        public void CancelInFlight()
        {
            if (ActiveIsParakeet) _parakeet.CancelInFlight();
            else _whisper.CancelInFlight();
        }

        public Task WarmUpAsync(CancellationToken ct) =>
            ActiveIsParakeet ? _parakeet.WarmUpAsync(ct) : _whisper.WarmUpAsync(ct);

        public Task<string> TranscribeAsync(float[] samples, CancellationToken ct) =>
            ActiveIsParakeet ? _parakeet.TranscribeAsync(samples, ct) : _whisper.TranscribeAsync(samples, ct);

        public Task TranscribeStreamAsync(float[] samples, Action<string> onPart, CancellationToken ct,
            bool cancelPrevious = false, bool liveMode = false)
        {
            return ActiveIsParakeet
                ? _parakeet.TranscribeStreamAsync(samples, onPart, ct, cancelPrevious, liveMode)
                : _whisper.TranscribeStreamAsync(samples, onPart, ct, cancelPrevious, liveMode);
        }

        public void Dispose()
        {
            if (_disposed) return;
            _disposed = true;
            _parakeet.Dispose();
            _whisper.Dispose();
        }
    }
}
