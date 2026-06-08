namespace SmartInterview
{
    /// <summary>
    /// Energy-based voice detector (simple VAD) on the 16 kHz mono system audio.
    /// Receives the incoming chunks and detects the speech "segments" separated by silence:
    /// - SpeechStarted: a new sentence/question has begun.
    /// - SpeechProgress: speech accumulated so far (for live transcription).
    /// - SegmentReady: the sentence has ended (prolonged silence) → ready for the AI.
    /// </summary>
    public sealed class VoiceSegmenter
    {
        private const int Rate = 16000;

        private int _silenceToEnd;
        private int _minSpeech;
        private readonly int _progressEvery;

        private readonly List<float> _seg = new();
        private bool _inSpeech;
        private int _silence;
        private int _speech;
        private int _sinceProgress;

        public event Action? SpeechStarted;
        public event Action<float[]>? SpeechProgress;
        public event Action<float[]>? SegmentReady;

        // Parameters adjustable at runtime from the settings panel.
        // Higher threshold: background noise (~0.01-0.015 RMS) must NOT exceed it,
        // only the actual voice. The slider now goes up to 0.1 (like LiveVersion).
        public const float DefaultThreshold = 0.022f;
        // Long pause before closing the sentence: a brief hesitation mid-question
        // must NOT split the utterance (otherwise the AI only sees the final part).
        public const int DefaultSilenceMs = 1300;
        public const int DefaultMinSpeechMs = 500;

        /// <summary>Energy threshold (RMS) above which audio is considered "voice".</summary>
        public float Threshold { get; set; } = DefaultThreshold;

        /// <summary>Silence (ms) after speech that closes the sentence.</summary>
        public int SilenceMs
        {
            get => _silenceToEnd * 1000 / Rate;
            set => _silenceToEnd = Rate * Math.Max(100, value) / 1000;
        }

        /// <summary>Minimum duration (ms) of speech for a segment to count as a question.</summary>
        public int MinSpeechMs
        {
            get => _minSpeech * 1000 / Rate;
            set => _minSpeech = Rate * Math.Max(50, value) / 1000;
        }

        public VoiceSegmenter()
        {
            SilenceMs = DefaultSilenceMs;
            MinSpeechMs = DefaultMinSpeechMs;
            _progressEvery = Rate / 2; // ~0.5s live preview cadence
        }

        public void Reset()
        {
            _seg.Clear();
            _inSpeech = false;
            _silence = 0;
            _speech = 0;
            _sinceProgress = 0;
        }

        public void Push(float[] chunk)
        {
            if (chunk.Length == 0) return;

            double sum = 0;
            for (int i = 0; i < chunk.Length; i++) sum += chunk[i] * chunk[i];
            float rms = (float)Math.Sqrt(sum / chunk.Length);
            bool voiced = rms > Threshold;

            if (voiced)
            {
                if (!_inSpeech)
                {
                    _inSpeech = true;
                    _seg.Clear();
                    _speech = 0;
                    _silence = 0;
                    _sinceProgress = 0;
                    SpeechStarted?.Invoke();
                }
                _seg.AddRange(chunk);
                _speech += chunk.Length;
                _silence = 0;
                _sinceProgress += chunk.Length;
                if (_sinceProgress >= _progressEvery)
                {
                    _sinceProgress = 0;
                    SpeechProgress?.Invoke(_seg.ToArray());
                }
            }
            else if (_inSpeech)
            {
                _seg.AddRange(chunk); // include a bit of trailing audio
                _silence += chunk.Length;
                if (_silence >= _silenceToEnd)
                {
                    _inSpeech = false;
                    if (_speech >= _minSpeech)
                        SegmentReady?.Invoke(_seg.ToArray());
                    _seg.Clear();
                }
            }
        }
    }
}
