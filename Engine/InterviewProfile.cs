using System.Text.Json;

namespace SmartInterview
{
    /// <summary>Candidate context injected into the AI system prompt (CV, role, stack).</summary>
    public sealed class InterviewProfile
    {
        public string Role { get; set; } = "";
        public string TechStack { get; set; } = "";
        public string JobDescription { get; set; } = "";
        public string Experience { get; set; } = "";

        public bool HasContent =>
            !string.IsNullOrWhiteSpace(Role) ||
            !string.IsNullOrWhiteSpace(TechStack) ||
            !string.IsNullOrWhiteSpace(JobDescription) ||
            !string.IsNullOrWhiteSpace(Experience);

        /// <summary>Block appended to the system prompt when any field is set.</summary>
        public string ToPromptBlock()
        {
            if (!HasContent) return "";
            var sb = new System.Text.StringBuilder();
            sb.AppendLine();
            sb.AppendLine("CANDIDATE CONTEXT (facts you may use; do NOT invent experience or skills not listed here):");
            if (!string.IsNullOrWhiteSpace(Role))
                sb.AppendLine($"- Target role: {Role.Trim()}");
            if (!string.IsNullOrWhiteSpace(TechStack))
                sb.AppendLine($"- Primary tech stack: {TechStack.Trim()}");
            if (!string.IsNullOrWhiteSpace(JobDescription))
                sb.AppendLine($"- Job / interview focus: {TrimBlock(JobDescription)}");
            if (!string.IsNullOrWhiteSpace(Experience))
                sb.AppendLine($"- Background & experience: {TrimBlock(Experience)}");
            sb.AppendLine("- Tailor answers to this profile when relevant; stay honest — if something is not in the profile, answer generically as a capable candidate without claiming specific employers, projects, or years you were not given.");
            return sb.ToString();
        }

        private static string TrimBlock(string s)
        {
            s = s.Trim().Replace("\r\n", " ").Replace('\n', ' ');
            return s.Length > 1200 ? s.Substring(0, 1200) + "…" : s;
        }
    }

    /// <summary>
    /// Persists the interview profile in the registry (HKCU\Software\SmartInterview),
    /// consistent with other app settings.
    /// </summary>
    internal static class ProfileStore
    {
        private const string KeyRole = "ProfileRole";
        private const string KeyTechStack = "ProfileTechStack";
        private const string KeyJobDescription = "ProfileJobDescription";
        private const string KeyExperience = "ProfileExperience";
        private const string PromptKey = "InterviewSetupPrompt";

        private static readonly JsonSerializerOptions LegacyJsonOpts = new()
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase
        };

        /// <summary>Legacy path used before registry storage; migrated once on load if present.</summary>
        private static string LegacyFilePath =>
            Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                "SmartInterview", "profile.json");

        public static InterviewProfile Load()
        {
            var profile = new InterviewProfile
            {
                Role = RegistryStore.GetString(KeyRole) ?? "",
                TechStack = RegistryStore.GetString(KeyTechStack) ?? "",
                JobDescription = RegistryStore.GetString(KeyJobDescription) ?? "",
                Experience = RegistryStore.GetString(KeyExperience) ?? ""
            };

            if (!profile.HasContent && TryLoadLegacyFile(out var legacy))
            {
                Save(legacy);
                TryDeleteLegacyFile();
                return legacy;
            }

            return profile;
        }

        public static void Save(InterviewProfile profile)
        {
            RegistryStore.SetString(KeyRole, profile.Role.Trim());
            RegistryStore.SetString(KeyTechStack, profile.TechStack.Trim());
            RegistryStore.SetString(KeyJobDescription, profile.JobDescription.Trim());
            RegistryStore.SetString(KeyExperience, profile.Experience.Trim());
        }

        /// <summary>True on first launch until the user skips or opens setup once.</summary>
        public static bool ShouldOfferSetupPrompt()
        {
            var v = RegistryStore.GetString(PromptKey);
            return v != "done" && v != "skipped";
        }

        public static void MarkSetupPromptSkipped() =>
            RegistryStore.SetString(PromptKey, "skipped");

        public static void MarkSetupPromptDone() =>
            RegistryStore.SetString(PromptKey, "done");

        private static bool TryLoadLegacyFile(out InterviewProfile profile)
        {
            profile = new InterviewProfile();
            try
            {
                if (!File.Exists(LegacyFilePath)) return false;
                var json = File.ReadAllText(LegacyFilePath);
                profile = JsonSerializer.Deserialize<InterviewProfile>(json, LegacyJsonOpts) ?? new InterviewProfile();
                return profile.HasContent;
            }
            catch { return false; }
        }

        private static void TryDeleteLegacyFile()
        {
            try { if (File.Exists(LegacyFilePath)) File.Delete(LegacyFilePath); }
            catch { /* best effort */ }
        }
    }
}
