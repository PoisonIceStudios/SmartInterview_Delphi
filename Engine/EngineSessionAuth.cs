using System.Security.Cryptography;
using System.Text;

namespace SmartInterview.Engine;

internal static class EngineSessionAuth
{
    public const string SessionEnvVar = "SMARTINTERVIEW_SESSION";
    public const string LicenseEnvVar = "SMARTINTERVIEW_LICENSE";
    private const string TokenPrefix = "SI_SESSION";
    private const string TokenVersion = "v1";
    private const string HmacSecret = "SmartInterview|EngineSession|v1|hmac";

    private static bool _authenticated;
    private static string? _sessionToken;

    public static bool IsAuthenticated => _authenticated;

#if DIAGNOSTIC_LOG
    public static bool DiagnosticBypassActive { get; private set; }
#endif

    public static bool TryAuthenticateFromEnvironment(out string? error)
    {
        error = null;
        var token = Environment.GetEnvironmentVariable(SessionEnvVar);
        var license = Environment.GetEnvironmentVariable(LicenseEnvVar);
        if (TryValidateToken(token, license, out error))
        {
            _authenticated = true;
            _sessionToken = token;
            return true;
        }

#if DIAGNOSTIC_LOG
        DiagnosticBypassActive = true;
        _authenticated = true;
        _sessionToken = null;
        LogEngine("[auth] DIAGNOSTIC_LOG bypass — engine running without license handshake.");
        return true;
#else
        _authenticated = false;
        _sessionToken = null;
        return false;
#endif
    }

    public static bool TryConfirmStartupToken(string? sessionToken, out string? error)
    {
        if (!_authenticated)
        {
            error = "unauthorized";
            return false;
        }

        if (string.IsNullOrWhiteSpace(sessionToken))
        {
            error = "session_token is required";
            return false;
        }

        if (!string.IsNullOrEmpty(_sessionToken) &&
            !string.Equals(sessionToken, _sessionToken, StringComparison.Ordinal))
        {
            error = "session_token mismatch";
            return false;
        }

        error = null;
        return true;
    }

    public static bool TryValidateToken(string? token, string? licenseKey, out string? error)
    {
        error = null;
        if (string.IsNullOrWhiteSpace(token))
        {
            error = "missing session token";
            return false;
        }
        if (string.IsNullOrWhiteSpace(licenseKey))
        {
            error = "missing license key";
            return false;
        }

        var parts = token.Split('.');
        if (parts.Length != 5 ||
            !string.Equals(parts[0], TokenPrefix, StringComparison.Ordinal) ||
            !string.Equals(parts[1], TokenVersion, StringComparison.Ordinal))
        {
            error = "invalid session token format";
            return false;
        }

        if (!long.TryParse(parts[2], out var expiryUnix))
        {
            error = "invalid session expiry";
            return false;
        }

        var nowUnix = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        if (nowUnix > expiryUnix)
        {
            error = "session token expired";
            return false;
        }

        var machineId = parts[3];
        var localMachine = MachineFingerprint.NormalizedRequestCode();
        if (!string.Equals(machineId, localMachine, StringComparison.OrdinalIgnoreCase))
        {
            error = "session token is not valid for this computer";
            return false;
        }

        var payload = $"{machineId}|{licenseKey}|{expiryUnix}";
        var expected = ComputeHmac(payload);
        var provided = Base64UrlDecode(parts[4]);
        if (provided.Length == 0 || !CryptographicOperations.FixedTimeEquals(expected, provided))
        {
            error = "invalid session signature";
            return false;
        }

        return true;
    }

    private static byte[] ComputeHmac(string payload)
    {
        var key = Encoding.UTF8.GetBytes(HmacSecret);
        var data = Encoding.UTF8.GetBytes(payload);
        return HMACSHA256.HashData(key, data);
    }

    private static byte[] Base64UrlDecode(string s)
    {
        var padded = s.Replace('-', '+').Replace('_', '/');
        switch (padded.Length % 4)
        {
            case 2: padded += "=="; break;
            case 3: padded += "="; break;
        }
        try
        {
            return Convert.FromBase64String(padded);
        }
        catch
        {
            return [];
        }
    }

    private static void LogEngine(string message) =>
        Console.Error.WriteLine($"[SmartInterview.Engine] {message}");
}
