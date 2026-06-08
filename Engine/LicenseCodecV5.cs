using System.Security.Cryptography;
using System.Text;

namespace SmartInterview.Engine;

internal static class LicenseCodecV5
{
    public const string KeyPrefix = "SI5-";
    private const byte Magic = 0x55;
    private const int PayloadBytes = 21;
    private const int SigBytes = 64;
    private const int TotalBytes = 85;
    private const int Base32Chars = 136;
    private const int Groups = 34;
    private const string Base32Alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

    private static readonly byte[] PublicKeyBlob = Convert.FromHexString(
        "45435331200000001FC80934B34F5AD860ECD715B3A9225FF88387B95DCBB5774096644" +
        "FF95D506B7D56E98C5D09EB9B3CAAC1C703087E4940E63B807AF1ABB47FD796A80341FFD0");

    public static bool IsV5Key(string licenseKey) =>
        licenseKey.Trim().StartsWith("SI5", StringComparison.OrdinalIgnoreCase);

    public static string NormalizeKeyV5(string licenseKey)
    {
        var s = licenseKey.Trim().ToUpperInvariant();
        if (s.StartsWith("SI5-", StringComparison.Ordinal))
            s = s[4..];
        else if (s.StartsWith("SI5", StringComparison.Ordinal))
            s = s[3..];
        return s.Replace("-", "", StringComparison.Ordinal);
    }

    public static bool TryDecodePayload(string licenseKey, out LicensePayload payload, out string? error)
    {
        payload = default;
        error = null;

        if (!IsV5Key(licenseKey))
        {
            error = "Not a v5 license key.";
            return false;
        }

        var normalized = NormalizeKeyV5(licenseKey);
        if (normalized.Length != Base32Chars)
        {
            error = "License key format is invalid.";
            return false;
        }

        try
        {
            var combined = DecodeBase32(normalized, TotalBytes);
            var payloadBytes = combined.AsSpan(0, PayloadBytes).ToArray();
            var sigBytes = combined.AsSpan(PayloadBytes, SigBytes).ToArray();

            if (!TryParsePayload(payloadBytes, out payload, out error))
                return false;

            var hash = SHA256.HashData(payloadBytes);
            if (!VerifySignature(hash, sigBytes))
            {
                error = "License signature is invalid.";
                return false;
            }

            return true;
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
        var expected = LicenseCodec.NormalizeUsername(expectedUsername);
        if (string.IsNullOrEmpty(expected))
        {
            error = "Enter your forum username.";
            return false;
        }

        if (!TryDecodePayload(licenseKey, out var payload, out error))
            return false;

        if (!string.Equals(LicenseCodec.NormalizeUsername(payload.ForumUsername), expected,
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

        if (LicenseCodec.IsExpired(payload, utcNow))
        {
            error = "This license has expired. Enter a new license code from the seller.";
            return false;
        }

        return true;
    }

    private static bool TryParsePayload(byte[] plain, out LicensePayload payload, out string? error)
    {
        payload = default;
        error = null;

        if (plain.Length != PayloadBytes || plain[0] != Magic)
        {
            error = "License key format is invalid (expected v5).";
            return false;
        }

        var flags = plain[1];
        var expiryUnixDay = BitConverter.ToUInt32(plain, 2);
        var issuedUnixDay = BitConverter.ToUInt32(plain, 6);
        var len = plain[10];
        if (len < 1 || len > LicenseCodec.MaxUsernameLen || 11 + len > PayloadBytes)
        {
            error = "License key format is invalid.";
            return false;
        }

        var userNorm = LicenseCodec.NormalizeUsername(Encoding.UTF8.GetString(plain, 11, len));
        if (string.IsNullOrEmpty(userNorm))
        {
            error = "License username is missing.";
            return false;
        }

        payload = new LicensePayload
        {
            ForumUsername = userNorm,
            Active = (flags & LicenseCodec.FlagActive) != 0,
            Lifetime = (flags & LicenseCodec.FlagLifetime) != 0,
            ExpiryUnixDay = expiryUnixDay,
            IssuedUnixDay = issuedUnixDay,
            Version = 5
        };
        return true;
    }

    private static bool VerifySignature(byte[] hash, byte[] signature)
    {
        if (signature.Length != SigBytes || PublicKeyBlob.Length < 72)
            return false;

        var x = PublicKeyBlob.AsSpan(8, 32).ToArray();
        var y = PublicKeyBlob.AsSpan(40, 32).ToArray();
        using var ecdsa = ECDsa.Create(ECCurve.NamedCurves.nistP256);
        var parameters = new ECParameters
        {
            Curve = ECCurve.NamedCurves.nistP256,
            Q = new ECPoint { X = x, Y = y }
        };
        ecdsa.ImportParameters(parameters);
        return ecdsa.VerifyHash(hash, signature, DSASignatureFormat.IeeeP1363FixedFieldConcatenation);
    }

    private static byte[] DecodeBase32(string encoded, int outBytes)
    {
        var result = new byte[outBytes];
        var buffer = 0;
        var bits = 0;
        var outLen = 0;

        foreach (var c in encoded)
        {
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
