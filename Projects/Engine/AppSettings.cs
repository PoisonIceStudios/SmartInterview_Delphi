namespace SmartInterview
{
    public enum AnswerLength
    {
        Short = 0,
        Medium = 1,
        Long = 2,
    }

    /// <summary>Registry-backed app preferences (model, answer length, automatic-mode VAD).</summary>
    internal static class AppSettings
    {
        public static AnswerLength GetAnswerLength()
        {
            int v = RegistryStore.GetInt("AnswerLength", (int)AnswerLength.Medium);
            return Enum.IsDefined(typeof(AnswerLength), v) ? (AnswerLength)v : AnswerLength.Medium;
        }

        public static void SetAnswerLength(AnswerLength length) =>
            RegistryStore.SetInt("AnswerLength", (int)length);

        public static ResponseIntelligence GetResponseIntelligence()
        {
            int v = RegistryStore.GetInt("ResponseIntelligence", -1);
            if (v < 0)
            {
                // First launch: pick a default that fits this machine, then remember it.
                var auto = HardwareProbe.RecommendedLevel();
                SetResponseIntelligence(auto);
                return auto;
            }
            return Enum.IsDefined(typeof(ResponseIntelligence), v) ? (ResponseIntelligence)v : ResponseIntelligence.Balanced;
        }

        public static void SetResponseIntelligence(ResponseIntelligence level) =>
            RegistryStore.SetInt("ResponseIntelligence", (int)level);

        public static TranscriptionIntelligence GetTranscriptionIntelligence()
        {
            int v = RegistryStore.GetInt("TranscriptionIntelligence", -1);
            if (v < 0)
            {
                var auto = HardwareProbe.RecommendedTranscriptionLevel();
                SetTranscriptionIntelligence(auto);
                return auto;
            }
            return Enum.IsDefined(typeof(TranscriptionIntelligence), v)
                ? (TranscriptionIntelligence)v
                : TranscriptionIntelligence.Balanced;
        }

        public static void SetTranscriptionIntelligence(TranscriptionIntelligence level) =>
            RegistryStore.SetInt("TranscriptionIntelligence", (int)level);

        public static (int numPredict, string promptHint) GetAnswerLengthOptions(AnswerLength length) => length switch
        {
            // SHORT: a low token cap is a hard limit that guarantees brevity even if the model
            // would otherwise ramble.
            AnswerLength.Short => (140,
                "ANSWER LENGTH — SHORT (STRICT): Answer in 1–2 short sentences only, about 30–45 words total. " +
                "Give just the single core point. Do NOT add examples, background, lists, or caveats. Stop as soon as the point is made."),
            // LONG: a high cap plus a *structured* instruction forces real elaboration instead of
            // a slightly longer paragraph.
            AnswerLength.Long => (2048,
                "ANSWER LENGTH — LONG (STRICT): Give a thorough, in-depth answer of AT LEAST 4 substantial paragraphs, about 300–450 words. " +
                "Cover, in order: (1) the core point, (2) why it matters in practice, (3) trade-offs or alternatives, (4) a concrete example from your experience. " +
                "Develop each point with real detail. Do NOT be brief, do NOT stop early, do NOT summarise in a few lines."),
            _ => (800,
                "ANSWER LENGTH — MEDIUM: Answer in about 5–8 sentences, around 110–180 words: the key idea explained clearly and completely, " +
                "with a short concrete example when useful. Complete enough to fully satisfy the interviewer — but not a multi-paragraph essay."),
        };

        public static void ApplyVadTo(VoiceSegmenter seg)
        {
            int thresh = RegistryStore.GetInt("VadThreshold", -1);
            if (thresh >= 0)
                seg.Threshold = thresh / 1000f * 0.1f;

            int silence = RegistryStore.GetInt("VadSilenceMs", -1);
            if (silence >= 200) seg.SilenceMs = silence;

            int min = RegistryStore.GetInt("VadMinSpeechMs", -1);
            if (min >= 100) seg.MinSpeechMs = min;
        }

        public static void SaveVad(VoiceSegmenter seg)
        {
            RegistryStore.SetInt("VadThreshold", (int)Math.Round(seg.Threshold / 0.1f * 1000f));
            RegistryStore.SetInt("VadSilenceMs", seg.SilenceMs);
            RegistryStore.SetInt("VadMinSpeechMs", seg.MinSpeechMs);
        }

        public static void SaveVadDefaults()
        {
            RegistryStore.SetInt("VadThreshold", (int)Math.Round(VoiceSegmenter.DefaultThreshold / 0.1f * 1000f));
            RegistryStore.SetInt("VadSilenceMs", VoiceSegmenter.DefaultSilenceMs);
            RegistryStore.SetInt("VadMinSpeechMs", VoiceSegmenter.DefaultMinSpeechMs);
        }
    }
}
