using System.Net.Http.Headers;
using System.Security.Cryptography;

namespace SmartInterview
{
    /// <summary>
    /// Downloads the Parakeet (sherpa-onnx) model files with SHA-256 verification.
    /// A model is a folder of 4-5 files; progress is aggregated over the total byte count
    /// so the UI sees one smooth 0..1 bar, same contract as WhisperModelDownloader.
    /// </summary>
    internal static class SherpaModelDownloader
    {
        private const double VerifyProgress = 0.99;

        public static async Task EnsureModelAsync(TranscriptionIntelligence level,
            Action<double?>? progress, CancellationToken ct)
        {
            var info = SherpaModelCatalog.Get(level);
            var dir = SherpaModelCatalog.DirFor(level);
            Directory.CreateDirectory(dir);

            long totalBytes = info.TotalBytes;
            long doneBytes = 0;

            foreach (var f in info.Files)
            {
                var path = Path.Combine(dir, f.FileName);

                if (File.Exists(path) && await IsValidAsync(path, f, ct))
                {
                    doneBytes += f.SizeBytes;
                    progress?.Invoke(Math.Min(VerifyProgress, (double)doneBytes / totalBytes));
                    continue;
                }

                try { if (File.Exists(path)) File.Delete(path); } catch { }
                var tmp = path + ".download";
                try { if (File.Exists(tmp)) File.Delete(tmp); } catch { }

                using var http = CreateHttpClient();
                using var resp = await http.GetAsync(f.Url, HttpCompletionOption.ResponseHeadersRead, ct);
                resp.EnsureSuccessStatusCode();

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
                        progress?.Invoke(Math.Min(VerifyProgress - 0.01,
                            (double)(doneBytes + read) / totalBytes));
                    }
                }

                if (!await IsValidAsync(tmp, f, ct))
                {
                    try { File.Delete(tmp); } catch { }
                    throw new InvalidOperationException(
                        $"Downloaded transcription model file '{f.FileName}' failed verification and was discarded.");
                }

                if (File.Exists(path)) File.Delete(path);
                File.Move(tmp, path);
                doneBytes += f.SizeBytes;
                progress?.Invoke(Math.Min(VerifyProgress, (double)doneBytes / totalBytes));
            }

            progress?.Invoke(1.0);
        }

        private static async Task<bool> IsValidAsync(string file, SherpaModelFile info, CancellationToken ct)
        {
            try
            {
                var fi = new FileInfo(file);
                if (!fi.Exists || fi.Length != info.SizeBytes)
                    return false;
                if (string.IsNullOrEmpty(info.Sha256))
                    return true; // small non-LFS file: exact size is the only check available

                await using var fs = File.OpenRead(file);
                using var sha = SHA256.Create();
                var buf = new byte[1 << 20];
                int n;
                while ((n = await fs.ReadAsync(buf, ct)) > 0)
                    sha.TransformBlock(buf, 0, n, null, 0);
                sha.TransformFinalBlock([], 0, 0);
                var hash = sha.Hash;
                return hash != null && string.Equals(
                    Convert.ToHexString(hash), info.Sha256, StringComparison.OrdinalIgnoreCase);
            }
            catch { return false; }
        }

        internal static void DeleteModelArtifacts(TranscriptionIntelligence level)
        {
            try
            {
                var dir = SherpaModelCatalog.DirFor(level);
                if (Directory.Exists(dir))
                    Directory.Delete(dir, recursive: true);
            }
            catch { /* best effort */ }
        }

        private static HttpClient CreateHttpClient()
        {
            var http = new HttpClient { Timeout = TimeSpan.FromHours(2) };
            http.DefaultRequestHeaders.UserAgent.Add(new ProductInfoHeaderValue("SmartInterview", "1.0"));
            return http;
        }
    }
}
