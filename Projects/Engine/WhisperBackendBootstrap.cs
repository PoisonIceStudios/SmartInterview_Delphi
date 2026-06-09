using Whisper.net.LibraryLoader;

namespace SmartInterview;

/// <summary>
/// Selects Whisper.net native backend. CUDA on supported NVIDIA GPUs; Vulkan GPU on Blackwell
/// (RTX 50) until CUDA prebuilts include sm_120; CPU as last resort.
/// Must run before any WhisperFactory call.
/// </summary>
internal static class WhisperBackendBootstrap
{
    private static bool _configured;

    public static void Configure(Action<string>? log = null)
    {
        if (_configured)
            return;

        try
        {
            var gpu = HardwareProbe.GetPrimaryNvidiaGpuName();
            if (HardwareProbe.HasNvidiaGpu())
            {
                if (HardwareProbe.IsBlackwellNvidiaGpu())
                {
                    // ALWAYS Vulkan on Blackwell, even with SMARTINTERVIEW_FORCE_CUDA: the Whisper
                    // CUDA prebuilts misbehave on sm_120 (crashes or garbage transcriptions), and
                    // transcription accuracy is non-negotiable. The force-CUDA toggle only affects
                    // the LLM backend (NativeBackendBootstrap), where CUDA brings the speed win.
                    RuntimeOptions.RuntimeLibraryOrder =
                    [
                        RuntimeLibrary.Vulkan,
                        RuntimeLibrary.Cpu,
                    ];
                    log?.Invoke($"Whisper backend: Vulkan GPU on Blackwell ({gpu ?? "NVIDIA"}).");
                }
                else
                {
                    RuntimeOptions.RuntimeLibraryOrder =
                    [
                        RuntimeLibrary.Cuda12,
                        RuntimeLibrary.Cuda,
                        RuntimeLibrary.Vulkan,
                        RuntimeLibrary.Cpu,
                    ];
                    log?.Invoke($"Whisper backend: CUDA preferred on {gpu ?? "NVIDIA"} (Cuda12 → Cuda13 → Vulkan → CPU).");
                }
            }
            else
            {
                RuntimeOptions.RuntimeLibraryOrder =
                [
                    RuntimeLibrary.Vulkan,
                    RuntimeLibrary.Cpu,
                ];
                log?.Invoke("Whisper backend: Vulkan preferred (CPU fallback).");
            }

            _configured = true;
        }
        catch (Exception ex)
        {
            log?.Invoke($"Whisper backend configuration warning: {ex.Message}");
        }
    }
}
