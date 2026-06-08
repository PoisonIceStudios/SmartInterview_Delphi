using System.Text.RegularExpressions;

namespace SmartInterview;

/// <summary>
/// Parses llama.cpp log lines to learn how many layers were actually offloaded to the GPU.
/// Requested GpuLayerCount (-1 = all) can differ when the native backend falls back to CPU.
/// </summary>
internal static class GpuLoadTelemetry
{
    private static readonly Regex OffloadPattern = new(
        @"offloaded\s+(\d+)\s*/\s*(\d+)\s+layers",
        RegexOptions.Compiled | RegexOptions.IgnoreCase | RegexOptions.CultureInvariant);

    private static int? _offloaded;
    private static int? _total;

    public static void Reset()
    {
        _offloaded = null;
        _total = null;
    }

    public static void TryParseLog(string? message)
    {
        if (string.IsNullOrWhiteSpace(message))
            return;
        var match = OffloadPattern.Match(message);
        if (!match.Success)
            return;
        _offloaded = int.Parse(match.Groups[1].Value);
        _total = int.Parse(match.Groups[2].Value);
    }

    /// <summary>
    /// Effective layer count for UI/status: -1 when all layers are on GPU, 0 for CPU-only.
    /// Falls back to the requested value when offload logs were not seen.
    /// </summary>
    public static int EffectiveGpuLayerCount(int requestedLayers)
    {
        if (_offloaded is null)
            return requestedLayers < 0 ? -1 : requestedLayers;

        if (_offloaded.Value == 0)
            return 0;

        if (_total is > 0 && _offloaded == _total)
            return -1;

        return _offloaded.Value;
    }
}
