namespace SmartInterview
{
    /// <summary>
    /// Central filesystem locations. Models (Whisper + AI) are stored in a "models"
    /// subfolder next to the executable so they stay self-contained with the program and
    /// don't clutter the OS. If that folder isn't writable (e.g. the app is installed under
    /// Program Files), it transparently falls back to %LOCALAPPDATA%\SmartInterview\models.
    /// When the engine subprocess runs from EngineDeploy/, it reuses the host app's models
    /// folder (one level up) so models are not downloaded or loaded twice.
    /// </summary>
    internal static class AppPaths
    {
        private static string? _modelsDir;

        public static string ModelsDir => _modelsDir ??= ResolveModelsDir();

        private static readonly string[] KnownModelFiles =
        {
            "ggml-small.bin",
            "response-balanced.bin",
            "response-fast.bin",
            "response-max.bin",
        };

        private static bool HasExistingModels(string dir)
        {
            if (!Directory.Exists(dir)) return false;
            try
            {
                foreach (var name in KnownModelFiles)
                    if (File.Exists(Path.Combine(dir, name))) return true;
            }
            catch { /* fall through */ }
            return false;
        }

        private static string? TryHostModelsDir()
        {
            var fromEnv = Environment.GetEnvironmentVariable("SMARTINTERVIEW_MODELS_DIR");
            if (!string.IsNullOrWhiteSpace(fromEnv) && HasExistingModels(fromEnv))
                return Path.GetFullPath(fromEnv);

            var baseDir = Path.GetFullPath(AppContext.BaseDirectory.TrimEnd(
                Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar));
            if (string.Equals(Path.GetFileName(baseDir), "EngineDeploy", StringComparison.OrdinalIgnoreCase))
            {
                var parent = Directory.GetParent(baseDir)?.FullName;
                if (parent != null)
                {
                    var sibling = Path.Combine(parent, "models");
                    if (HasExistingModels(sibling))
                        return sibling;
                }
            }

            return null;
        }

        private static string ResolveModelsDir()
        {
            try
            {
                var host = TryHostModelsDir();
                if (host != null && TryEnsureWritable(host))
                    return host;
            }
            catch { /* fall through */ }

            // Preferred: <program folder>\models
            try
            {
                var beside = Path.Combine(AppContext.BaseDirectory, "models");
                if (TryEnsureWritable(beside)) return beside;
            }
            catch { /* fall through */ }

            // Fallback: per-user app data (always writable)
            var local = Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "SmartInterview", "models");
            Directory.CreateDirectory(local);
            return local;
        }

        private static bool TryEnsureWritable(string dir)
        {
            try
            {
                Directory.CreateDirectory(dir);
                var probe = Path.Combine(dir, ".writetest");
                File.WriteAllText(probe, "");
                File.Delete(probe);
                return true;
            }
            catch { return false; }
        }
    }
}
