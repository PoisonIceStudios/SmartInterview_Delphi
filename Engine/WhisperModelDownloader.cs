using System.Net.Http.Headers;
using System.Security.Cryptography;

namespace SmartInterview
{
    /// <summary>Downloads Whisper ggml models with SHA-256 verification.</summary>
    internal static class WhisperModelDownloader
    {
        private const double VerifyProgress = 0.99;

        public static async Task EnsureModelAsync(TranscriptionIntelligence level,
            Action<double?>? progress, CancellationToken ct)
        {
            var info = WhisperModelCatalog.Get(level);
            var path = WhisperModelCatalog.PathFor(level);

            MigrateLegacyModel(level, path);

            if (File.Exists(path))
            {
                progress?.Invoke(VerifyProgress);
                if (await IsValidAsync(path, info, ct, progress))
                    return;
            }

            if (File.Exists(path))
            {
                try { File.Delete(path); } catch { /* re-download corrupt/partial */ }
            }

            var tmp = path + ".download";
            try { if (File.Exists(tmp)) File.Delete(tmp); } catch { }

            using var http = CreateHttpClient();
            using var resp = await http.GetAsync(info.Url, HttpCompletionOption.ResponseHeadersRead, ct);
            resp.EnsureSuccessStatusCode();

            long total = info.SizeBytes > 0 ? info.SizeBytes : (resp.Content.Headers.ContentLength ?? 0);

            progress?.Invoke(0);

            await using (var src = await resp.Content.ReadAsStreamAsync(ct))
            await using (var dst = File.Create(tmp))
            {
                var buf = new byte[1 << 20];
                long read = 0;
                int n;
                while ((n = await src.ReadAsync(buf, ct)) > 0)
                {
                    await dst.WriteAsync(buf.AsMemory(0, n), ct);
                    read += n;
                    if (total > 0)
                        progress?.Invoke(Math.Min(VerifyProgress - 0.01, (double)read / total));
                    else
                        progress?.Invoke(null);
                }
            }

            progress?.Invoke(VerifyProgress);

            if (!await IsValidAsync(tmp, info, ct, progress))
            {
                try { File.Delete(tmp); } catch { }
                throw new InvalidOperationException(
                    "The downloaded transcription model failed integrity verification and was discarded.");
            }

            if (File.Exists(path)) File.Delete(path);
            File.Move(tmp, path);
            progress?.Invoke(1.0);
        }

        internal static async Task<bool> IsValidAsync(string file, WhisperModelInfo info, CancellationToken ct,
            Action<double?>? progress = null)
        {
            try
            {
                var fi = new FileInfo(file);
                if (!fi.Exists || fi.Length < info.SizeBytes * 95 / 100)
                    return false;

                await using var fs = File.OpenRead(file);
                long total = fi.Length;
                long read = 0;
                using var sha = SHA256.Create();
                var buf = new byte[1 << 20];
                int n;
                while ((n = await fs.ReadAsync(buf, ct)) > 0)
                {
                    read += n;
                    if (read == total)
                        sha.TransformFinalBlock(buf, 0, n);
                    else
                        sha.TransformBlock(buf, 0, n, null, 0);

                    if (progress != null && total > 0)
                    {
                        var frac = (double)read / total;
                        progress.Invoke(VerifyProgress + frac * (1.0 - VerifyProgress));
                    }
                }

                var hash = sha.Hash;
                if (hash == null)
                    return false;

                var ok = string.Equals(Convert.ToHexString(hash), info.Sha256,
                    StringComparison.OrdinalIgnoreCase);
                if (ok)
                    progress?.Invoke(1.0);
                return ok;
            }
            catch { return false; }
        }

        internal static void DeleteModelArtifacts(TranscriptionIntelligence level)
        {
            var path = WhisperModelCatalog.PathFor(level);
            TryDelete(path);
            TryDelete(path + ".download");

            if (level == TranscriptionIntelligence.Fast)
            {
                TryDelete(Path.Combine(AppPaths.ModelsDir, "ggml-small.bin"));
                TryDelete(Path.Combine(AppPaths.ModelsDir, "whisper-balanced.bin"));
            }
            else if (level == TranscriptionIntelligence.Balanced)
            {
                TryDelete(Path.Combine(AppPaths.ModelsDir, "ggml-medium.bin"));
                TryDelete(Path.Combine(AppPaths.ModelsDir, "whisper-max.bin"));
            }
            else if (level == TranscriptionIntelligence.Max)
            {
                TryDelete(Path.Combine(AppPaths.ModelsDir, "ggml-large-v3.bin"));
            }
        }

        private static void TryDelete(string path)
        {
            try { if (File.Exists(path)) File.Delete(path); } catch { }
        }

        private static HttpClient CreateHttpClient()
        {
            var http = new HttpClient { Timeout = TimeSpan.FromHours(2) };
            http.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("SmartInterview", "1.0"));
            return http;
        }

        private static void MigrateLegacyModel(TranscriptionIntelligence level, string path)
        {
            if (File.Exists(path)) return;

            string? legacy = level switch
            {
                TranscriptionIntelligence.Fast =>
                    FirstExisting(
                        Path.Combine(AppPaths.ModelsDir, "ggml-small.bin"),
                        Path.Combine(AppPaths.ModelsDir, "whisper-balanced.bin")),
                TranscriptionIntelligence.Balanced =>
                    FirstExisting(
                        Path.Combine(AppPaths.ModelsDir, "ggml-medium.bin"),
                        Path.Combine(AppPaths.ModelsDir, "whisper-max.bin")),
                TranscriptionIntelligence.Max =>
                    Path.Combine(AppPaths.ModelsDir, "ggml-large-v3.bin"),
                _ => null,
            };

            if (legacy == null || !File.Exists(legacy)) return;
            try { File.Copy(legacy, path); } catch { }
        }

        private static string? FirstExisting(params string[] paths)
        {
            foreach (var p in paths)
                if (File.Exists(p)) return p;
            return null;
        }
    }
}
