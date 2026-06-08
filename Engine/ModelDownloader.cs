using System.Net.Http.Headers;
using System.Security.Cryptography;

namespace SmartInterview
{
    /// <summary>
    /// Downloads the local GGUF model for a given intelligence level, with progress and
    /// SHA-256 integrity verification. Mirrors the Whisper model download flow so a
    /// truncated, corrupted, or substituted file is rejected rather than loaded.
    /// </summary>
    internal static class ModelDownloader
    {
        private const double VerifyProgress = 0.99;

        /// <summary>Ensures the model for <paramref name="level"/> is present and valid.
        /// progress: 0..1 (null = unknown size). No-op if already installed and valid.</summary>
        public static async Task EnsureModelAsync(ResponseIntelligence level,
            Action<double?>? progress, CancellationToken ct)
        {
            var info = ModelCatalog.Get(level);
            var path = ModelCatalog.PathFor(level);

            if (File.Exists(path) && await IsValidAsync(path, info, ct))
                return;

            if (File.Exists(path))
            {
                try { File.Delete(path); } catch { }
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

            if (!await IsValidAsync(tmp, info, ct))
            {
                try { File.Delete(tmp); } catch { }
                throw new InvalidOperationException(
                    "The downloaded AI model failed integrity verification and was discarded.");
            }

            if (File.Exists(path)) File.Delete(path);
            File.Move(tmp, path);
            progress?.Invoke(1.0);
        }

        private static async Task<bool> IsValidAsync(string file, LocalModelInfo info, CancellationToken ct)
        {
            try
            {
                var fi = new FileInfo(file);
                if (!fi.Exists || fi.Length != info.SizeBytes) return false;
                await using var fs = File.OpenRead(file);
                byte[] hash = await SHA256.HashDataAsync(fs, ct);
                return string.Equals(Convert.ToHexString(hash), info.Sha256,
                    StringComparison.OrdinalIgnoreCase);
            }
            catch { return false; }
        }

        private static HttpClient CreateHttpClient()
        {
            var http = new HttpClient { Timeout = TimeSpan.FromHours(2) };
            http.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("SmartInterview", "1.0"));
            return http;
        }
    }
}
