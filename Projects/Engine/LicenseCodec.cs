using System.Security.Cryptography;
using System.Text;

namespace SmartInterview.Engine;

internal readonly struct LicensePayload
{
    public string ForumUsername { get; init; }
    public bool Active { get; init; }
    public bool Lifetime { get; init; }
    public uint ExpiryUnixDay { get; init; }
    public uint IssuedUnixDay { get; init; }
    public byte Version { get; init; }
}

internal static class LicenseCodec
{
    public const int KeyChars = 32;
    public const int KeyGroups = 8;
    public const int MaxUsernameLen = 30;
    public const byte FlagActive = 0x01;
    public const byte FlagLifetime = 0x02;

    private const string HmacSecret = "SmartInterview|License|v4|hmac";
    private const string XorSecret = "SmartInterview|License|v4|xor";
    private const byte Magic = 0x54;
    private const int PayloadBytes = 20;
    private const string Base32Alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
    private static readonly DateTime UnixEpoch = new(1970, 1, 1, 0, 0, 0, DateTimeKind.Utc);

    public static string NormalizeUsername(string username) =>
        username.Trim().ToLowerInvariant();

    public static string NormalizeKey(string licenseKey) =>
        licenseKey.Replace("-", "", StringComparison.Ordinal).Trim().ToUpperInvariant();

    public static string FormatKey(string rawKey)
    {
        var raw = NormalizeKey(rawKey);
        return string.Join('-', Enumerable.Range(0, KeyGroups).Select(i => raw.Substring(i * 4, 4)));
    }

    public static string Encode(string forumUsername, DateTime expiryDateLocal, bool lifetime, bool active)
    {
        var userNorm = NormalizeUsername(forumUsername);
        if (string.IsNullOrEmpty(userNorm))
            throw new ArgumentException("Forum username is required.");

        var userUtf8 = Encoding.UTF8.GetBytes(userNorm);
        if (userUtf8.Length > MaxUsernameLen)
            throw new ArgumentException($"Forum username is too long (max {MaxUsernameLen} characters).");

        byte flags = 0;
        if (active) flags |= FlagActive;
        uint expiryUnixDay = 0;
        if (lifetime)
            flags |= FlagLifetime;
        else
            expiryUnixDay = UnixDayFromLocalDate(expiryDateLocal);

        var plain = BuildPlaintext(userUtf8, flags, expiryUnixDay);
        var cipher = XorCipher(plain);
        return FormatKey(EncodeBase32(cipher, KeyChars));
    }

    public static bool TryDecodePayload(string licenseKey, out LicensePayload payload, out string? error)
    {
        payload = default;
        error = null;

        if (LicenseCodecV5.IsV5Key(licenseKey))
            return LicenseCodecV5.TryDecodePayload(licenseKey, out payload, out error);

        var normalized = NormalizeKey(licenseKey);
        if (normalized.Length != KeyChars)
        {
            error = "License key format is invalid.";
            return false;
        }

        try
        {
            var cipher = DecodeBase32(normalized, PayloadBytes);
            var plain = XorCipher(cipher);
            return TryParsePlaintext(plain, out payload, out error);
        }
        catch (Exception ex)
        {
            error = "License key could not be read: " + ex.Message;
            return false;
        }
    }

    public static bool TryValidate(string licenseKey, string expectedUsername, DateTime utcNow, out string? error)
    {
        error = null;
        var expected = NormalizeUsername(expectedUsername);
        if (string.IsNullOrEmpty(expected))
        {
            error = "Enter your forum username.";
            return false;
        }

        if (LicenseCodecV5.IsV5Key(licenseKey))
            return LicenseCodecV5.TryValidate(licenseKey, expectedUsername, utcNow, out error);

        if (!TryDecodePayload(licenseKey, out var payload, out error))
            return false;

        if (!string.Equals(
                NormalizeUsername(payload.ForumUsername),
                expected,
                StringComparison.OrdinalIgnoreCase))
        {
            error = "This license is not valid for the forum username entered.";
            return false;
        }

        if (!payload.Active)
        {
            error = "This license has been deactivated.";
            return false;
        }

        if (IsExpired(payload, utcNow))
        {
            error = "This license has expired. Enter a new license code from the seller.";
            return false;
        }

        var expectedKey = Encode(
            expected,
            ExpiryToDate(payload.ExpiryUnixDay),
            payload.Lifetime,
            payload.Active);
        if (!string.Equals(NormalizeKey(expectedKey), NormalizeKey(licenseKey), StringComparison.Ordinal))
        {
            error = "License key is invalid.";
            return false;
        }

        return true;
    }

    public static bool IsExpired(LicensePayload payload, DateTime utcNow)
    {
        if (!payload.Active)
            return true;
        if (payload.Lifetime)
            return false;
        return UnixDayFromUtc(utcNow) > payload.ExpiryUnixDay;
    }

    public static string FormatExpiry(LicensePayload payload) =>
        payload.Lifetime ? "Lifetime" : ExpiryToDate(payload.ExpiryUnixDay).ToString("yyyy-MM-dd");

    public static uint UnixDayFromUtc(DateTime utc) =>
        (uint)(utc.ToUniversalTime().Date - UnixEpoch.Date).TotalDays;

    public static uint UnixDayFromLocalDate(DateTime localDate)
    {
        var endOfDayLocal = localDate.Date.AddHours(23).AddMinutes(59).AddSeconds(59);
        return UnixDayFromUtc(endOfDayLocal.ToUniversalTime());
    }

    public static DateTime ExpiryToDate(uint expiryUnixDay) =>
        UnixEpoch.AddDays(expiryUnixDay);

    private static byte[] Keystream()
    {
        var keyBytes = Encoding.UTF8.GetBytes(XorSecret);
        var stream = HMACSHA256.HashData(keyBytes, Encoding.UTF8.GetBytes("stream"));
        return stream.AsSpan(0, PayloadBytes).ToArray();
    }

    private static byte[] BuildPlaintext(byte[] userUtf8, byte flags, uint expiryUnixDay)
    {
        var plain = new byte[PayloadBytes];
        plain[0] = Magic;
        plain[1] = flags;
        Buffer.BlockCopy(BitConverter.GetBytes(expiryUnixDay), 0, plain, 2, 4);
        plain[6] = (byte)userUtf8.Length;
        Buffer.BlockCopy(userUtf8, 0, plain, 7, userUtf8.Length);

        var canon = $"{Encoding.UTF8.GetString(userUtf8)}|{expiryUnixDay}|{flags}";
        var hmac = HMACSHA256.HashData(Encoding.UTF8.GetBytes(HmacSecret), Encoding.UTF8.GetBytes(canon));
        var fillStart = 7 + userUtf8.Length;
        Buffer.BlockCopy(hmac, 0, plain, fillStart, PayloadBytes - fillStart);
        return plain;
    }

    private static byte[] XorCipher(byte[] plain)
    {
        var stream = Keystream();
        var result = new byte[plain.Length];
        for (var i = 0; i < plain.Length; i++)
            result[i] = (byte)(plain[i] ^ stream[i % stream.Length]);
        return result;
    }

    private static bool TryParsePlaintext(byte[] plain, out LicensePayload payload, out string? error)
    {
        payload = default;
        error = null;

        if (plain.Length != PayloadBytes)
        {
            error = "License payload size is invalid.";
            return false;
        }

        if (plain[0] != Magic)
        {
            error = "License key format is invalid (expected v4).";
            return false;
        }

        var flags = plain[1];
        var expiryUnixDay = BitConverter.ToUInt32(plain, 2);
        var len = plain[6];
        if (len < 1 || len > MaxUsernameLen || 7 + len > PayloadBytes)
        {
            error = "License key format is invalid.";
            return false;
        }

        var userNorm = NormalizeUsername(Encoding.UTF8.GetString(plain, 7, len));
        if (string.IsNullOrEmpty(userNorm))
        {
            error = "License username is missing.";
            return false;
        }

        payload = new LicensePayload
        {
            ForumUsername = userNorm,
            Active = (flags & FlagActive) != 0,
            Lifetime = (flags & FlagLifetime) != 0,
            ExpiryUnixDay = expiryUnixDay,
            IssuedUnixDay = 0,
            Version = 4
        };

        var canon = $"{userNorm}|{expiryUnixDay}|{flags}";
        var hmac = HMACSHA256.HashData(Encoding.UTF8.GetBytes(HmacSecret), Encoding.UTF8.GetBytes(canon));
        var fillStart = 7 + len;
        for (var i = fillStart; i < PayloadBytes; i++)
        {
            if (plain[i] != hmac[i - fillStart])
            {
                error = "License key is invalid.";
                return false;
            }
        }

        return true;
    }

    private static string EncodeBase32(byte[] data, int chars)
    {
        var result = new StringBuilder(chars);
        var buffer = 0;
        var bits = 0;

        foreach (var b in data)
        {
            buffer = (buffer << 8) | b;
            bits += 8;
            while (bits >= 5 && result.Length < chars)
            {
                bits -= 5;
                result.Append(Base32Alphabet[(buffer >> bits) & 0x1F]);
            }
            if (result.Length >= chars)
                break;
        }

        // Flush remaining real bits (bits is 0..4 here) into a final 5-bit group,
        // left-aligning them so decode recovers the last byte intact.
        if (result.Length < chars && bits > 0)
        {
            result.Append(Base32Alphabet[(buffer << (5 - bits)) & 0x1F]);
            bits = 0;
        }
        while (result.Length < chars)
            result.Append(Base32Alphabet[0]);

        return result.ToString();
    }

    private static byte[] DecodeBase32(string encoded, int outBytes)
    {
        var result = new byte[outBytes];
        var buffer = 0;
        var bits = 0;
        var outLen = 0;

        foreach (var c in encoded)
        {
            if (c == '-')
                continue;

            var idx = Base32Alphabet.IndexOf(c);
            if (idx < 0)
                throw new ArgumentException("License key contains invalid characters.");

            buffer = (buffer << 5) | idx;
            bits += 5;
            while (bits >= 8 && outLen < outBytes)
            {
                bits -= 8;
                result[outLen++] = (byte)((buffer >> bits) & 0xFF);
            }
        }

        if (outLen != outBytes)
            throw new ArgumentException("License key length is invalid.");

        return result;
    }
}
