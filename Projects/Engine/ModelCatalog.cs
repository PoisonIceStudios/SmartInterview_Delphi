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
        long ApproxVramBytes,
        bool HybridThinking);

    /// <summary>
    /// The three local models behind the intelligence levels. GGUF Q4_K_M builds from
    /// bartowski. Qwen3 generation: same speed class per tier as the previous Qwen2.5
    /// set, but markedly better instruction-following, reasoning, and answer depth.
    /// Qwen3-8B/14B are hybrid-thinking models: HybridThinking=true makes the client
    /// prefill an empty think block so they answer directly (no visible reasoning, no
    /// wasted tokens). Qwen3-4B-Instruct-2507 is a pure instruct model (no thinking).
    /// </summary>
    internal static class ModelCatalog
    {
        private const string Base = "https://huggingface.co/bartowski";

        public static LocalModelInfo Get(ResponseIntelligence level) => level switch
        {
            ResponseIntelligence.Fast => new LocalModelInfo(
                FileName: "response-fast.bin",
                Url: $"{Base}/Qwen_Qwen3-4B-Instruct-2507-GGUF/resolve/main/Qwen_Qwen3-4B-Instruct-2507-Q4_K_M.gguf",
                Sha256: "2fde00ce69dd4899c70d020845e2638353015bba0fdf161b3eb965f2bca4464e",
                SizeBytes: 2_497_280_736,
                Label: "Fast",
                Description: "Quick responses, solid accuracy — best for lower-end PCs (~2.5 GB).",
                ApproxVramBytes: 3_500_000_000,
                HybridThinking: false),

            ResponseIntelligence.Max => new LocalModelInfo(
                FileName: "response-max.bin",
                Url: $"{Base}/Qwen_Qwen3-14B-GGUF/resolve/main/Qwen_Qwen3-14B-Q4_K_M.gguf",
                Sha256: "915913e22399475dbe6c968ac014d9f1fbe08975e489279aede9d5c7b2c98eb6",
                SizeBytes: 9_001_753_632,
                Label: "Maximum accuracy",
                Description: "Most accurate, detailed answers — needs more memory and time (~9 GB).",
                ApproxVramBytes: 11_000_000_000,
                HybridThinking: true),

            _ => new LocalModelInfo(
                FileName: "response-balanced.bin",
                Url: $"{Base}/Qwen_Qwen3-8B-GGUF/resolve/main/Qwen_Qwen3-8B-Q4_K_M.gguf",
                Sha256: "54fffa050078e984116639c83dfb64b5aa6d4cd474e018b076777c632bbccccd",
                SizeBytes: 5_027_784_224,
                Label: "Balanced (recommended)",
                Description: "Good balance of accuracy and speed (~5 GB).",
                ApproxVramBytes: 7_000_000_000,
                HybridThinking: true),
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
