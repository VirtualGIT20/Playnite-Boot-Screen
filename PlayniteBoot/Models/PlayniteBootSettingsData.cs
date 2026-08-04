using System;
using System.Collections.Generic;

namespace PlayniteBoot.Models
{
    public class PlayniteBootSettingsData : ObservableObject
    {
        public const int CurrentSettingsVersion = 1;

        private int settingsVersion;
        private string playniteExecutable = "auto";
        private string launchArguments = "--hidesplashscreen";
        private string videoPath = string.Empty;
        private string monitor = "auto";
        private string videoStretch = "UniformToFill";
        private bool loopVideo;
        private bool waitForVideoEnd;
        private bool mute = true;
        private double volume = 1.0;
        private int minimumVideoMilliseconds = 900;
        private int readyStabilityMilliseconds = 500;
        private int startTimeoutSeconds = 45;
        private int videoReadyPositionMilliseconds = 180;
        private int videoReadyAdvanceSamples = 3;
        private int videoReadyTimeoutMilliseconds = 5000;
        private int fadeInMilliseconds = 80;
        private int fadeOutMilliseconds = 400;
        private bool hideMouseCursor = true;
        private bool logEnabled = true;
        private string shortcutName = "Playnite Fullscreen";
        private StreamingSettings streaming = new StreamingSettings();

        public static PlayniteBootSettingsData CreateDefault()
        {
            return new PlayniteBootSettingsData
            {
                SettingsVersion = CurrentSettingsVersion
            };
        }

        public int SettingsVersion { get => settingsVersion; set => SetValue(ref settingsVersion, value); }
        public string PlayniteExecutable { get => playniteExecutable; set => SetValue(ref playniteExecutable, value); }
        public string LaunchArguments { get => launchArguments; set => SetValue(ref launchArguments, value); }
        public string VideoPath { get => videoPath; set => SetValue(ref videoPath, value); }
        public string Monitor { get => monitor; set => SetValue(ref monitor, value); }
        public string VideoStretch { get => videoStretch; set => SetValue(ref videoStretch, value); }
        public bool LoopVideo { get => loopVideo; set => SetValue(ref loopVideo, value); }

        // When enabled, the overlay remains visible until both Playnite is ready
        // and the configured video reaches its natural end.
        public bool WaitForVideoEnd { get => waitForVideoEnd; set => SetValue(ref waitForVideoEnd, value); }

        public bool Mute { get => mute; set => SetValue(ref mute, value); }

        // Runtime value used by WPF MediaElement (0.0 to 1.0). The settings
        // view model exposes it as a familiar 0 to 100 percentage.
        public double Volume
        {
            get => volume;
            set
            {
                if (Math.Abs(volume - value) < 0.0001)
                {
                    return;
                }

                volume = value;
                OnPropertyChanged();
            }
        }


        public int MinimumVideoMilliseconds { get => minimumVideoMilliseconds; set => SetValue(ref minimumVideoMilliseconds, value); }
        public int ReadyStabilityMilliseconds { get => readyStabilityMilliseconds; set => SetValue(ref readyStabilityMilliseconds, value); }
        public int StartTimeoutSeconds { get => startTimeoutSeconds; set => SetValue(ref startTimeoutSeconds, value); }
        public int VideoReadyPositionMilliseconds { get => videoReadyPositionMilliseconds; set => SetValue(ref videoReadyPositionMilliseconds, value); }
        public int VideoReadyAdvanceSamples { get => videoReadyAdvanceSamples; set => SetValue(ref videoReadyAdvanceSamples, value); }
        public int VideoReadyTimeoutMilliseconds { get => videoReadyTimeoutMilliseconds; set => SetValue(ref videoReadyTimeoutMilliseconds, value); }
        public int FadeInMilliseconds { get => fadeInMilliseconds; set => SetValue(ref fadeInMilliseconds, value); }
        public int FadeOutMilliseconds { get => fadeOutMilliseconds; set => SetValue(ref fadeOutMilliseconds, value); }
        public bool HideMouseCursor { get => hideMouseCursor; set => SetValue(ref hideMouseCursor, value); }
        public bool LogEnabled { get => logEnabled; set => SetValue(ref logEnabled, value); }
        public string ShortcutName { get => shortcutName; set => SetValue(ref shortcutName, value); }
        public StreamingSettings Streaming { get => streaming; set => SetValue(ref streaming, value); }
    }
}
