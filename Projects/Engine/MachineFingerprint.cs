using System.Security.Cryptography;
using System.Text;
using Microsoft.Win32;

namespace SmartInterview.Engine;

/// <summary>
/// Mirrors Delphi uMachineFingerprint — same salt, material, and base32 request code.
/// </summary>
internal static class MachineFingerprint
{
    private const string AppSalt = "SmartInterview|v1|machine";
    private const string Base32Alphabet = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";

    public static string NormalizedRequestCode() =>
        Normalize(FormatRequestCode(ComputeHash()));

    public static string Normalize(string code) =>
        code.Replace("-", "", StringComparison.Ordinal).Trim().ToUpperInvariant();

    private static byte[] ComputeHash()
    {
        var material = CollectMaterial();
        var utf8 = Encoding.UTF8.GetBytes($"{AppSalt}|{material}");
        return SHA256.HashData(utf8);
    }

    private static string CollectMaterial()
    {
        var parts = new List<string>();

        try
        {
            using var key = Registry.LocalMachine.OpenSubKey(@"SOFTWARE\Microsoft\Cryptography");
            var guid = key?.GetValue("MachineGuid") as string;
            if (!string.IsNullOrWhiteSpace(guid))
                parts.Add($"mg:{guid.Trim()}");
        }
        catch { /* best effort */ }

        var uuid = QueryWmi("Win32_ComputerSystemProduct", "UUID");
        if (!string.IsNullOrWhiteSpace(uuid))
            parts.Add($"mb:{uuid}");

        var bios = QueryWmi("Win32_BIOS", "SerialNumber");
        if (!string.IsNullOrWhiteSpace(bios))
            parts.Add($"bios:{bios}");

        if (parts.Count == 0)
            parts.Add($"fallback:{Environment.MachineName}");

        return string.Join('|', parts);
    }

    private static string? QueryWmi(string wmiClass, string prop)
    {
        try
        {
            using var searcher = new System.Management.ManagementObjectSearcher(
                $"SELECT {prop} FROM {wmiClass}");
            foreach (var obj in searcher.Get())
            {
                var value = obj[prop]?.ToString()?.Trim();
                if (string.IsNullOrWhiteSpace(value))
                    continue;
                if (value.Equals("To be filled by O.E.M.", StringComparison.OrdinalIgnoreCase))
                    continue;
                if (value.Equals("Default string", StringComparison.OrdinalIgnoreCase))
                    continue;
                if (value.Replace("-", "").Replace("0", "") == "")
                    continue;
                return value;
            }
        }
        catch { /* WMI unavailable */ }
        return null;
    }

    private static string FormatRequestCode(byte[] hash)
    {
        var raw = EncodeBase32(hash, 16);
        return $"{raw[..4]}-{raw[4..8]}-{raw[8..12]}-{raw[12..16]}";
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
        while (result.Length < chars)
        {
            buffer <<= 5;
            bits += 5;
            result.Append(Base32Alphabet[buffer & 0x1F]);
        }
        return result.ToString();
    }
}
