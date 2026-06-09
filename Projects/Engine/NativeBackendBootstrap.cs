using LLama.Native;

namespace SmartInterview;

/// <summary>
/// Selects llama.cpp native backend (CUDA on NVIDIA, Vulkan otherwise, CPU fallback).
/// Must run before any LLamaSharp model call.
/// </summary>
internal static class NativeBackendBootstrap
{
    private static bool _configured;

    public static void Configure(Action<string>? log = null)
    {
        if (_configured)
            return;

        var baseDir = AppContext.BaseDirectory;
        try
        {
            var cfg = NativeLibraryConfig.All
                .WithAutoFallback(true)
                .WithSearchDirectory(baseDir);

            if (log != null)
            {
                cfg.WithLogCallback((level, message) =>
                {
                    var line = message.TrimEnd('\r', '\n');
                    GpuLoadTelemetry.TryParseLog(line);
                    log($"[{level}] {line}");
                });
            }
            else
            {
                cfg.WithLogCallback((_, message) =>
                    GpuLoadTelemetry.TryParseLog(message.TrimEnd('\r', '\n')));
            }

            if (HardwareProbe.HasNvidiaGpu())
            {
                if (HardwareProbe.IsBlackwellNvidiaGpu() && !HardwareProbe.ForceCudaOnBlackwell())
                {
                    // Blackwell: early CUDA12 prebuilts lacked sm_120; Vulkan uses GPU reliably on
                    // RTX 50. Set SMARTINTERVIEW_FORCE_CUDA=1 to prefer CUDA (faster) on CUDA 12.8+.
                    cfg.WithCuda(false).WithVulkan(true);
                    log?.Invoke($"Native backend: Vulkan GPU on Blackwell ({HardwareProbe.GetPrimaryNvidiaGpuName()}). Set SMARTINTERVIEW_FORCE_CUDA=1 to try CUDA.");
                }
                else
                {
                    // CUDA preferred, Vulkan fallback (WithAutoFallback handles a failed CUDA load).
                    cfg.WithCuda(true).WithVulkan(true);
                    log?.Invoke($"Native backend: CUDA preferred on {HardwareProbe.GetPrimaryNvidiaGpuName()} (Vulkan fallback).");
                }
            }
            else
            {
                cfg.WithCuda(false).WithVulkan(true);
                log?.Invoke($"Native backend: Vulkan preferred (base={baseDir}).");
            }

            NativeApi.llama_empty_call();
            _configured = true;
        }
        catch (Exception ex)
        {
            log?.Invoke($"Native backend configuration warning: {ex.Message}");
        }
    }

}
