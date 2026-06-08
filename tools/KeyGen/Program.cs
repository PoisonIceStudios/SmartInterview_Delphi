using System.Security.Cryptography;

var ecdsa = ECDsa.Create(ECCurve.NamedCurves.nistP256);
var p = ecdsa.ExportParameters(true);
const int cbKey = 32;

var pubBlob = new byte[8 + cbKey * 2];
BitConverter.GetBytes(0x31534345u).CopyTo(pubBlob, 0);
BitConverter.GetBytes((uint)cbKey).CopyTo(pubBlob, 4);
p.Q.X!.CopyTo(pubBlob, 8);
p.Q.Y!.CopyTo(pubBlob, 8 + cbKey);

var privBlob = new byte[8 + cbKey * 3];
BitConverter.GetBytes(0x32534345u).CopyTo(privBlob, 0);
BitConverter.GetBytes((uint)cbKey).CopyTo(privBlob, 4);
p.D!.CopyTo(privBlob, 8);
p.Q.X!.CopyTo(privBlob, 8 + cbKey);
p.Q.Y!.CopyTo(privBlob, 8 + cbKey * 2);

var root = AppContext.BaseDirectory;
while (!string.IsNullOrEmpty(root) && !File.Exists(Path.Combine(root, "Projects.groupproj")))
    root = Path.GetDirectoryName(root) ?? string.Empty;
if (string.IsNullOrEmpty(root))
    throw new InvalidOperationException("Repository root not found.");
var outDir = Path.Combine(root, "Projects", "LicenseManager", "Keys");
Directory.CreateDirectory(outDir);
File.WriteAllBytes(Path.Combine(outDir, "license_signing.pub"), pubBlob);
File.WriteAllBytes(Path.Combine(outDir, "license_signing.priv"), privBlob);
Console.WriteLine($"Wrote keys to {outDir}");
Console.WriteLine("PUB_HEX=" + Convert.ToHexString(pubBlob));
