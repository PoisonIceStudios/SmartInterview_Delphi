using System.Security.Cryptography;
using System.Text;
using Microsoft.Win32;

namespace SmartInterview
{
    /// <summary>
    /// Persistent application settings stored in the Windows registry under
    /// HKEY_CURRENT_USER\Software\SmartInterview. Used for state that must survive
    /// restarts (for example, whether the end-user license has been accepted).
    /// All accessors fail safe: any registry error is swallowed and treated as
    /// "no value", so the app keeps working even with restricted permissions.
    /// </summary>
    internal static class RegistryStore
    {
        private const string KeyPath = @"Software\SmartInterview";

        // ---- Typed helpers ----

        private static RegistryKey OpenWrite() =>
            Registry.CurrentUser.CreateSubKey(KeyPath, writable: true);

        private static RegistryKey? OpenRead() =>
            Registry.CurrentUser.OpenSubKey(KeyPath, writable: false);

        public static string? GetString(string name)
        {
            try { using var k = OpenRead(); return k?.GetValue(name) as string; }
            catch { return null; }
        }

        public static void SetString(string name, string value)
        {
            try { using var k = OpenWrite(); k.SetValue(name, value, RegistryValueKind.String); }
            catch { /* read-only environment: ignore */ }
        }

        public static int GetInt(string name, int fallback = 0)
        {
            try { using var k = OpenRead(); return k?.GetValue(name) is int i ? i : fallback; }
            catch { return fallback; }
        }

        public static void SetInt(string name, int value)
        {
            try { using var k = OpenWrite(); k.SetValue(name, value, RegistryValueKind.DWord); }
            catch { /* read-only environment: ignore */ }
        }

        // ---- EULA acceptance ----
        //
        // The acceptance is stored as a token bound to this machine + Windows user,
        // not as a plain "1". A value copied from another machine therefore does not
        // unlock the gate, and a casual edit of the flag will not match. This is a
        // light deterrent only: a determined attacker can still reproduce it, so it
        // is not relied upon for anything security-critical.

        private const string EulaValue = "EulaToken";

        /// <summary>The EULA revision currently shipped. Bump it to force re-acceptance.</summary>
        public const int EulaVersion = 2;

        public static bool IsEulaAccepted()
        {
            var stored = GetString(EulaValue);
            return !string.IsNullOrEmpty(stored) &&
                   string.Equals(stored, ExpectedEulaToken(), StringComparison.Ordinal);
        }

        public static void SetEulaAccepted() => SetString(EulaValue, ExpectedEulaToken());

        private static string ExpectedEulaToken()
        {
            // Bind the token to the machine and the EULA version so it is not portable.
            string material = $"{Environment.MachineName}|{Environment.UserName}|eula-v{EulaVersion}";
            byte[] hash = SHA256.HashData(Encoding.UTF8.GetBytes(material));
            return Convert.ToHexString(hash);
        }
    }
}
