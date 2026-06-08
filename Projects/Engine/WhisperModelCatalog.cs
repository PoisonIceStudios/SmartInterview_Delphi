namespace SmartInterview
{
    /// <summary>
    /// User-facing transcription quality level. Higher levels are more accurate but slower.
    /// </summary>
    public enum TranscriptionIntelligence
    {
        Fast = 0,
        Balanced = 1,
        Max = 2,
    }

    /// <summary>Metadata for a downloadable Whisper ggml model.</summary>
    public sealed record WhisperModelInfo(
        string FileName,
        string Url,
        string Sha256,
        long SizeBytes,
        string Label,
        string Description);

    /// <summary>The three Whisper models behind transcription intelligence levels.</summary>
    internal static class WhisperModelCatalog
    {
        private const string Base = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main";

        public static WhisperModelInfo Get(TranscriptionIntelligence level) => level switch
        {
            TranscriptionIntelligence.Fast => new WhisperModelInfo(
                FileName: "whisper-fast.bin",
                Url: $"{Base}/ggml-small.bin",
                Sha256: "1be3a9b2063867b937e64e2ec7483364a79917e157fa98c5d94b5c1fffea987b",
                SizeBytes: 487_601_967,
                Label: "Fast",
                Description: "Fast recognition for clear speech (~470 MB, ggml-small)."),

            TranscriptionIntelligence.Max => new WhisperModelInfo(
                FileName: "whisper-max.bin",
                Url: $"{Base}/ggml-large-v3.bin",
                Sha256: "64d182b440b98d5203c4f9bd541544d84c605196c4f7b845dfa11fb23594d1e2",
                SizeBytes: 3_095_033_483,
                Label: "Maximum accuracy",
                Description: "Best quality for noisy audio and similar-sounding words (~3.1 GB, ggml-large-v3)."),

            _ => new WhisperModelInfo(
                FileName: "whisper-balanced.bin",
                Url: $"{Base}/ggml-medium.bin",
                Sha256: "6c14d5adee5f86394037b4e4e8b59f1673b6cee10e3cf0b11bbdbee79c156208",
                SizeBytes: 1_533_763_059,
                Label: "Balanced (recommended)",
                Description: "Good balance of speed and accuracy for accents and background noise (~1.5 GB, ggml-medium)."),
        };

        public static string PathFor(TranscriptionIntelligence level) =>
            Path.Combine(AppPaths.ModelsDir, Get(level).FileName);

        public static bool IsInstalled(TranscriptionIntelligence level)
        {
            try
            {
                var path = PathFor(level);
                if (!File.Exists(path)) return false;
                return new FileInfo(path).Length == Get(level).SizeBytes;
            }
            catch { return false; }
        }
    }
}
