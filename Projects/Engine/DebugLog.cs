using System.Diagnostics;

namespace SmartInterview
{
    /// <summary>
    /// Lightweight diagnostic logger. Writes one timestamped line per call to
    /// %LOCALAPPDATA%\SmartInterview\debug.log. Used to trace the audio→transcription→AI
    /// pipeline when something doesn't reach the answer step. Best-effort: never throws.
    ///
    /// Disabled in normal builds: Write() is marked [Conditional("DIAGNOSTIC_LOG")], so unless
    /// the DIAGNOSTIC_LOG compilation symbol is defined the compiler strips every call site —
    /// no logging code ships in production and nothing is written to disk. To re-enable while
    /// debugging, add &lt;DefineConstants&gt;DIAGNOSTIC_LOG&lt;/DefineConstants&gt; to the build.
    /// </summary>
    internal static class DebugLog
    {
        private static readonly object _lock = new();
        private static readonly string _path = BuildPath();

        private static string BuildPath()
        {
            try
            {
                var dir = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                    "SmartInterview");
                Directory.CreateDirectory(dir);
                return Path.Combine(dir, "debug.log");
            }
            catch { return System.IO.Path.Combine(System.IO.Path.GetTempPath(), "SmartInterview-debug.log"); }
        }

        public static string FilePath => _path;

        [Conditional("DIAGNOSTIC_LOG")]
        public static void Write(string message)
        {
            try
            {
                lock (_lock)
                    File.AppendAllText(_path,
                        $"{DateTime.Now:HH:mm:ss.fff}  {message}{Environment.NewLine}");
            }
            catch { /* logging must never break the app */ }
        }
    }
}
