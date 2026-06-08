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
                    // CUDA prebuilts crash on sm_120 during model init; Vulkan uses the GPU safely.
                    RuntimeOptions.RuntimeLibraryOrder =
                    [
                        RuntimeLibrary.Vulkan,
                        RuntimeLibrary.Cpu,
                    ];
                    log?.Invoke($"Whisper backend: Vulkan GPU on Blackwell ({gpu ?? "NVIDIA"}). CUDA prebuilts skip sm_120.");
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
