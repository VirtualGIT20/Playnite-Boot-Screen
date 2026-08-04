using System.Collections.Generic;

namespace PlayniteBoot.Models
{
    public class StreamingSettings : ObservableObject
    {
        private bool enabled = true;
        private string monitor = "clientResolution";
        private int preloadReadyTimeoutMilliseconds = 6000;
        private int continueWaitTimeoutMilliseconds = 10000;
        private int preloadAbandonTimeoutMilliseconds = 30000;
        private string fallbackMode = "standalone";

        public bool Enabled { get => enabled; set => SetValue(ref enabled, value); }
        public string Monitor { get => monitor; set => SetValue(ref monitor, value); }
        public int PreloadReadyTimeoutMilliseconds { get => preloadReadyTimeoutMilliseconds; set => SetValue(ref preloadReadyTimeoutMilliseconds, value); }
        public int ContinueWaitTimeoutMilliseconds { get => continueWaitTimeoutMilliseconds; set => SetValue(ref continueWaitTimeoutMilliseconds, value); }
        public int PreloadAbandonTimeoutMilliseconds { get => preloadAbandonTimeoutMilliseconds; set => SetValue(ref preloadAbandonTimeoutMilliseconds, value); }
        public string FallbackMode { get => fallbackMode; set => SetValue(ref fallbackMode, value); }
    }
}
