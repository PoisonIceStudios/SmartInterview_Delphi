using System.Net.Http;
using System.Text.Json;

namespace SmartInterview.Engine;

internal static class OnlineTime
{
    private const string OfflineMsg =
        "An internet connection is required to verify the license. " +
        "Connect to the internet and try again.";

    public static bool TryFetchUtcNow(out DateTime utcNow, out string? error)
    {
        utcNow = default;
        error = null;

        if (TryFetchFromUrl("https://worldtimeapi.org/api/timezone/Etc/UTC", ParseWorldTimeApi, out utcNow, out error))
            return true;

        if (TryFetchFromUrl("https://timeapi.io/api/Time/current/zone?timeZone=UTC", ParseTimeApiIo, out utcNow, out error))
            return true;

        error = OfflineMsg;
        return false;
    }

    private static bool TryFetchFromUrl(string url, Func<string, DateTime?> parser, out DateTime utcNow, out string? error)
    {
        utcNow = default;
        error = null;
        try
        {
            using var client = new HttpClient { Timeout = TimeSpan.FromSeconds(8) };
            var body = client.GetStringAsync(url).GetAwaiter().GetResult();
            var parsed = parser(body);
            if (parsed.HasValue)
            {
                utcNow = parsed.Value;
                return true;
            }
            error = "Could not parse time server response.";
            return false;
        }
        catch (Exception ex)
        {
            error = ex.Message;
            return false;
        }
    }

    private static DateTime? ParseWorldTimeApi(string json)
    {
        using var doc = JsonDocument.Parse(json);
        if (!doc.RootElement.TryGetProperty("datetime", out var dt))
            return null;
        return dt.GetDateTimeOffset().UtcDateTime;
    }

    private static DateTime? ParseTimeApiIo(string json)
    {
        using var doc = JsonDocument.Parse(json);
        if (!doc.RootElement.TryGetProperty("dateTime", out var dt))
            return null;
        return dt.GetDateTime().ToUniversalTime();
    }
}
