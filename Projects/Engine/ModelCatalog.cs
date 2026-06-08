namespace SmartInterview
{
    /// <summary>
    /// User-facing "response intelligence" level. Higher levels are more accurate but
    /// need more memory and are slower. The underlying model name is intentionally NOT
    /// shown to the user — only precision/speed wording.
    /// </summary>
    public enum ResponseIntelligence
    {
        Fast = 0,       // small model — quick, light, good for mid-range PCs
        Balanced = 1,   // default — good balance of accuracy and speed
        Max = 2,        // large model — most accurate, needs more VRAM/time
    }

    /// <summary>Metadata for a downloadable local GGUF model behind an intelligence level.</summary>
    public sealed record LocalModelInfo(
        string FileName,
        string Url,
        string Sha256,
        long SizeBytes,
        string Label,
        string Description,
        long ApproxVramBytes);

    /// <summary>
    /// The three local models behind the intelligence levels. GGUF Q4_K_M builds from
    /// bartowski (same quantization as the previous Ollama model, so "Balanced" == parity).
    /// </summary>
    internal static class ModelCatalog
    {
        private const string Base = "https://huggingface.co/bartowski";

        public static LocalModelInfo Get(ResponseIntelligence level) => level switch
        {
            ResponseIntelligence.Fast => new LocalModelInfo(
                FileName: "response-fast.bin",
                Url: $"{Base}/Qwen2.5-3B-Instruct-GGUF/resolve/main/Qwen2.5-3B-Instruct-Q4_K_M.gguf",
                Sha256: "9c9f56a391a3abbd5b89d0245bf6106081bcc3173119d4229235dd9d23253f94",
                SizeBytes: 1_929_903_264,
                Label: "Fast",
                Description: "Quick responses, basic accuracy — best for lower-end PCs (~2 GB).",
                ApproxVramBytes: 3_000_000_000),

            ResponseIntelligence.Max => new LocalModelInfo(
                FileName: "response-max.bin",
                Url: $"{Base}/Qwen2.5-14B-Instruct-GGUF/resolve/main/Qwen2.5-14B-Instruct-Q4_K_M.gguf",
                Sha256: "e47ad95dad6ff848b431053b375adb5d39321290ea2c638682577dafca87c008",
                SizeBytes: 8_988_110_976,
                Label: "Maximum accuracy",
                Description: "Most accurate, detailed answers — needs more memory and time (~9 GB).",
                ApproxVramBytes: 11_000_000_000),

            _ => new LocalModelInfo(
                FileName: "response-balanced.bin",
                Url: $"{Base}/Qwen2.5-7B-Instruct-GGUF/resolve/main/Qwen2.5-7B-Instruct-Q4_K_M.gguf",
                Sha256: "65b8fcd92af6b4fefa935c625d1ac27ea29dcb6ee14589c55a8f115ceaaa1423",
                SizeBytes: 4_683_074_240,
                Label: "Balanced (recommended)",
                Description: "Good balance of accuracy and speed (~4.7 GB).",
                ApproxVramBytes: 6_500_000_000),
        };

        public static string PathFor(ResponseIntelligence level) =>
            Path.Combine(AppPaths.ModelsDir, Get(level).FileName);

        public static bool IsInstalled(ResponseIntelligence level)
        {
            try
            {
                var info = new FileInfo(PathFor(level));
                // Size match is a cheap "looks complete" check; full hash is verified on download.
                return info.Exists && info.Length == Get(level).SizeBytes;
            }
            catch { return false; }
        }
    }
}
