using System.Runtime.InteropServices;
using Microsoft.Win32;

namespace SmartInterview
{
    /// <summary>
    /// Lightweight hardware probing used to pick a sensible default "response intelligence"
    /// level on first launch: a capable GPU gets the Balanced model, a weak machine gets Fast.
    /// </summary>
    internal static class HardwareProbe
    {
        private const long GB = 1024L * 1024 * 1024;

        /// <summary>True when an NVIDIA display adapter is present.</summary>
        public static bool HasNvidiaGpu()
        {
            return !string.IsNullOrEmpty(GetPrimaryNvidiaGpuName());
        }

        /// <summary>
        /// RTX 50 / Blackwell (sm_120): Whisper.net and LLamaSharp CUDA prebuilts may crash or fall back to CPU.
        /// Vulkan GPU is used as a safe accelerator until sm_120 binaries ship.
        /// </summary>
        public static bool IsBlackwellNvidiaGpu()
        {
            var name = GetPrimaryNvidiaGpuName();
            if (string.IsNullOrEmpty(name)) return false;
            return name.Contains("RTX 50", StringComparison.OrdinalIgnoreCase)
                   || name.Contains("RTX 60", StringComparison.OrdinalIgnoreCase)
                   || name.Contains("Blackwell", StringComparison.OrdinalIgnoreCase);
        }

        /// <summary>
        /// Opt-in override (env <c>SMARTINTERVIEW_FORCE_CUDA=1</c>, "Force CUDA" menu toggle) to
        /// prefer CUDA on Blackwell (RTX 50xx) for the <b>LLM backend only</b>. Whisper always
        /// stays on Vulkan on Blackwell: its CUDA prebuilts misbehave on sm_120 (crashes or
        /// garbage transcriptions) and transcription accuracy is non-negotiable. Default off:
        /// the LLM also uses Vulkan unless this is set.
        /// </summary>
        public static bool ForceCudaOnBlackwell()
        {
            var v = Environment.GetEnvironmentVariable("SMARTINTERVIEW_FORCE_CUDA");
            return string.Equals(v, "1", StringComparison.Ordinal)
                || string.Equals(v, "true", StringComparison.OrdinalIgnoreCase)
                || string.Equals(v, "yes", StringComparison.OrdinalIgnoreCase);
        }

        public static string? GetPrimaryNvidiaGpuName()
        {
            string? best = null;
            long bestVram = 0;
            try
            {
                const string root =
                    @"SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}";
                using var key = Registry.LocalMachine.OpenSubKey(root);
                if (key == null) return null;
                foreach (var sub in key.GetSubKeyNames())
                {
                    if (!int.TryParse(sub, out _)) continue;
                    try
                    {
                        using var dev = key.OpenSubKey(sub);
                        if (dev == null) continue;
                        var provider = dev.GetValue("ProviderName") as string;
                        if (provider == null ||
                            !provider.Contains("NVIDIA", StringComparison.OrdinalIgnoreCase))
                            continue;

                        var desc = dev.GetValue("DriverDesc") as string;
                        var vram = ReadVramBytes(dev);
                        if (vram >= bestVram)
                        {
                            bestVram = vram;
                            best = desc;
                        }
                    }
                    catch { /* skip adapter */ }
                }
            }
            catch { /* registry not accessible */ }

            return best;
        }

        private static long ReadVramBytes(RegistryKey? dev)
        {
            if (dev == null) return 0;
            var val = dev.GetValue("HardwareInformation.qwMemorySize");
            return val switch
            {
                long l => l,
                byte[] b when b.Length == 8 => BitConverter.ToInt64(b, 0),
                int i => i,
                _ => 0
            };
        }

        /// <summary>Recommended level for first launch, based on dedicated VRAM (or RAM as fallback).</summary>
        public static ResponseIntelligence RecommendedLevel()
        {
            long vram = GetMaxDedicatedVramBytes();
            if (vram >= 6 * GB) return ResponseIntelligence.Balanced;   // 7B Q4 runs comfortably
            if (vram > 0) return ResponseIntelligence.Fast;             // known small/integrated GPU

            // VRAM unknown: use system RAM as a rough proxy.
            long ram = GetTotalPhysicalMemoryBytes();
            return ram >= 16 * GB ? ResponseIntelligence.Balanced : ResponseIntelligence.Fast;
        }

        /// <summary>Recommended Whisper tier on first launch (shifted up: small / medium / large-v3).</summary>
        public static TranscriptionIntelligence RecommendedTranscriptionLevel()
        {
            long vram = GetMaxDedicatedVramBytes();
            if (vram >= 10 * GB) return TranscriptionIntelligence.Max;
            if (vram >= 6 * GB) return TranscriptionIntelligence.Balanced;
            if (vram > 0) return TranscriptionIntelligence.Fast;

            long ram = GetTotalPhysicalMemoryBytes();
            return ram >= 16 * GB ? TranscriptionIntelligence.Balanced : TranscriptionIntelligence.Fast;
        }

        /// <summary>
        /// Largest dedicated GPU memory in bytes, read from the display adapters' registry
        /// (HardwareInformation.qwMemorySize — accurate 64-bit value). 0 if undetermined.
        /// </summary>
        public static long GetMaxDedicatedVramBytes()
        {
            long max = 0;
            try
            {
                const string root = @"SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}";
                using var key = Registry.LocalMachine.OpenSubKey(root);
                if (key == null) return 0;
                foreach (var sub in key.GetSubKeyNames())
                {
                    if (!int.TryParse(sub, out _)) continue;
                    try
                    {
                        using var dev = key.OpenSubKey(sub);
                        var bytes = ReadVramBytes(dev);
                        if (bytes > max) max = bytes;
                    }
                    catch { /* skip this adapter */ }
                }
            }
            catch { /* registry not accessible */ }
            return max;
        }

        public static long GetTotalPhysicalMemoryBytes()
        {
            try
            {
                var status = new MEMORYSTATUSEX();
                if (GlobalMemoryStatusEx(status)) return (long)status.ullTotalPhys;
            }
            catch { }
            return 0;
        }

        [StructLayout(LayoutKind.Sequential)]
        private sealed class MEMORYSTATUSEX
        {
            public uint dwLength = (uint)Marshal.SizeOf(typeof(MEMORYSTATUSEX));
            public uint dwMemoryLoad;
            public ulong ullTotalPhys;
            public ulong ullAvailPhys;
            public ulong ullTotalPageFile;
            public ulong ullAvailPageFile;
            public ulong ullTotalVirtual;
            public ulong ullAvailVirtual;
            public ulong ullAvailExtendedVirtual;
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool GlobalMemoryStatusEx([In, Out] MEMORYSTATUSEX lpBuffer);
    }
}
