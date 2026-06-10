namespace SmartInterview
{
    /// <summary>One downloadable file of a Parakeet model folder.</summary>
    public sealed record SherpaModelFile(string FileName, string Url, string? Sha256, long SizeBytes);

    /// <summary>Metadata for a Parakeet (sherpa-onnx NeMo transducer) model folder.</summary>
    public sealed record SherpaModelInfo(
        string FolderName,
        string EncoderFile,
        string DecoderFile,
        string JoinerFile,
        string Label,
        string Description,
        SherpaModelFile[] Files)
    {
        public long TotalBytes
        {
            get
            {
                long t = 0;
                foreach (var f in Files) t += f.SizeBytes;
                return t;
            }
        }
    }

    /// <summary>
    /// NVIDIA Parakeet TDT 0.6B v3 (25 European languages, auto language detection) exported to
    /// sherpa-onnx. Replaces Whisper for the Fast/Balanced transcription tiers: it tops the Open
    /// ASR leaderboard above whisper-large-v3, runs ~10x faster, and — being a transducer, not a
    /// text generator — it does not hallucinate "Grazie a tutti" style phrases on noise.
    /// The Max tier remains Whisper large-v3 (see WhisperModelCatalog) so the two engines can be
    /// compared live by switching tiers.
    /// </summary>
    internal static class SherpaModelCatalog
    {
        private const string BaseInt8 =
            "https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3-int8/resolve/main";
        private const string BaseFp32 =
            "https://huggingface.co/csukuangfj/sherpa-onnx-nemo-parakeet-tdt-0.6b-v3/resolve/main";

        /// <summary>True for the tiers backed by Parakeet (Fast/Balanced); Max stays Whisper.</summary>
        public static bool IsParakeetLevel(TranscriptionIntelligence level) =>
            level != TranscriptionIntelligence.Max;

        public static SherpaModelInfo Get(TranscriptionIntelligence level) => level switch
        {
            TranscriptionIntelligence.Fast => new SherpaModelInfo(
                FolderName: "parakeet-fast",
                EncoderFile: "encoder.int8.onnx",
                DecoderFile: "decoder.int8.onnx",
                JoinerFile: "joiner.int8.onnx",
                Label: "Fast",
                Description: "Parakeet v3 int8 — very fast, 25 languages, robust to noise (~670 MB).",
                Files:
                [
                    new SherpaModelFile("encoder.int8.onnx", $"{BaseInt8}/encoder.int8.onnx",
                        "acfc2b4456377e15d04f0243af540b7fe7c992f8d898d751cf134c3a55fd2247", 652_184_281),
                    new SherpaModelFile("decoder.int8.onnx", $"{BaseInt8}/decoder.int8.onnx",
                        "179e50c43d1a9de79c8a24149a2f9bac6eb5981823f2a2ed88d655b24248db4e", 11_845_275),
                    new SherpaModelFile("joiner.int8.onnx", $"{BaseInt8}/joiner.int8.onnx",
                        "3164c13fc2821009440d20fcb5fdc78bff28b4db2f8d0f0b329101719c0948b3", 6_355_277),
                    new SherpaModelFile("tokens.txt", $"{BaseInt8}/tokens.txt", null, 93_939),
                ]),

            // Balanced (default): full-precision Parakeet. encoder.onnx references the external
            // weights file (encoder.weights) by relative path, so both must sit in the folder.
            _ => new SherpaModelInfo(
                FolderName: "parakeet-accurate",
                EncoderFile: "encoder.onnx",
                DecoderFile: "decoder.onnx",
                JoinerFile: "joiner.onnx",
                Label: "Balanced (recommended)",
                Description: "Parakeet v3 full precision — best accuracy of the fast engine (~2.5 GB).",
                Files:
                [
                    new SherpaModelFile("encoder.onnx", $"{BaseFp32}/encoder.onnx",
                        "3eed7ce424bf8339ad09233533c687e2dbd07e74ccf5027b5e7344019ea373b0", 41_766_257),
                    new SherpaModelFile("encoder.weights", $"{BaseFp32}/encoder.weights",
                        "3af3f51af5f2d01dbbf5af47d42c7962a2c205f11004254bb4f2b979862f39a8", 2_435_420_160),
                    new SherpaModelFile("decoder.onnx", $"{BaseFp32}/decoder.onnx",
                        "d593cdb0e571f5a457ec2219af9968cbf6b0e8198e8f7839b40a8754593bf68c", 47_233_743),
                    new SherpaModelFile("joiner.onnx", $"{BaseFp32}/joiner.onnx",
                        "b9b0bcf88ac571902e69a6536223ed2d94885e981b85045410f1403d53121a63", 25_286_330),
                    new SherpaModelFile("tokens.txt", $"{BaseFp32}/tokens.txt", null, 93_939),
                ]),
        };

        public static string DirFor(TranscriptionIntelligence level) =>
            Path.Combine(AppPaths.ModelsDir, Get(level).FolderName);

        public static bool IsInstalled(TranscriptionIntelligence level)
        {
            try
            {
                var info = Get(level);
                var dir = DirFor(level);
                foreach (var f in info.Files)
                {
                    var path = Path.Combine(dir, f.FileName);
                    if (!File.Exists(path) || new FileInfo(path).Length != f.SizeBytes)
                        return false;
                }
                return true;
            }
            catch { return false; }
        }
    }
}
