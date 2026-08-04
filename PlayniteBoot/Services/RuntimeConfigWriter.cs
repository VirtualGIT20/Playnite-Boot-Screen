using PlayniteBoot.Models;
using System;
using System.Globalization;
using System.IO;
using System.Text;
using System.Web.Script.Serialization;

namespace PlayniteBoot.Services
{
    public class RuntimeConfigWriter
    {
        public const int CurrentConfigVersion = 1;

        private readonly RuntimePaths paths;
        private readonly JavaScriptSerializer serializer = new JavaScriptSerializer();

        public RuntimeConfigWriter(RuntimePaths paths)
        {
            this.paths = paths;
        }

        public void Write(PlayniteBootSettingsData settings)
        {
            Directory.CreateDirectory(paths.RuntimeDirectory);
            Directory.CreateDirectory(paths.LogsDirectory);

            var videoPath = NormalizeVideoPath(settings.VideoPath);
            var json = BuildJson(settings, videoPath);
            var tempPath = paths.ConfigPath + ".tmp";
            var backupPath = paths.ConfigPath + ".bak";

            File.WriteAllText(tempPath, json, new UTF8Encoding(false));

            if (File.Exists(paths.ConfigPath))
            {
                if (File.Exists(backupPath))
                {
                    File.Delete(backupPath);
                }

                File.Replace(tempPath, paths.ConfigPath, backupPath, true);
                if (File.Exists(backupPath))
                {
                    File.Delete(backupPath);
                }
            }
            else
            {
                File.Move(tempPath, paths.ConfigPath);
            }
        }

        private string NormalizeVideoPath(string configuredPath)
        {
            if (string.IsNullOrWhiteSpace(configuredPath) ||
                string.Equals(Path.GetFullPath(configuredPath), Path.GetFullPath(paths.DefaultVideoPath), StringComparison.OrdinalIgnoreCase))
            {
                return @".\media\boot-4k60.mp4";
            }

            return Path.GetFullPath(configuredPath);
        }

        private string BuildJson(PlayniteBootSettingsData s, string videoPath)
        {
            var streaming = s.Streaming ?? new StreamingSettings();
            var volume = Math.Max(0.0, Math.Min(1.0, s.Volume));
            var b = new StringBuilder();
            b.AppendLine("{");
            Append(b, "configVersion", CurrentConfigVersion, true);
            Append(b, "playniteExecutable", s.PlayniteExecutable, true);
            Append(b, "launchArguments", s.LaunchArguments, true);
            Append(b, "videoPath", videoPath, true);
            Append(b, "monitor", s.Monitor, true);
            Append(b, "videoStretch", s.VideoStretch, true);
            Append(b, "loopVideo", s.LoopVideo, true);
            Append(b, "waitForVideoEnd", s.WaitForVideoEnd, true);
            Append(b, "mute", s.Mute, true);
            Append(b, "volume", volume, true);
            b.AppendLine();
            Append(b, "minimumVideoMilliseconds", s.MinimumVideoMilliseconds, true);
            Append(b, "readyStabilityMilliseconds", s.ReadyStabilityMilliseconds, true);
            Append(b, "startTimeoutSeconds", s.StartTimeoutSeconds, true);
            b.AppendLine();
            Append(b, "videoReadyPositionMilliseconds", s.VideoReadyPositionMilliseconds, true);
            Append(b, "videoReadyAdvanceSamples", s.VideoReadyAdvanceSamples, true);
            Append(b, "videoReadyTimeoutMilliseconds", s.VideoReadyTimeoutMilliseconds, true);
            b.AppendLine();
            Append(b, "fadeInMilliseconds", s.FadeInMilliseconds, true);
            Append(b, "fadeOutMilliseconds", s.FadeOutMilliseconds, true);
            Append(b, "hideMouseCursor", s.HideMouseCursor, true);
            b.AppendLine();
            Append(b, "logEnabled", s.LogEnabled, true);
            Append(b, "logPath", @".\logs\PlayniteBoot.log", true);
            b.AppendLine();
            b.AppendLine("  \"streaming\": {");
            Append(b, "enabled", streaming.Enabled, true, 4);
            Append(b, "monitor", streaming.Monitor, true, 4);
            Append(b, "preloadReadyTimeoutMilliseconds", streaming.PreloadReadyTimeoutMilliseconds, true, 4);
            Append(b, "continueWaitTimeoutMilliseconds", streaming.ContinueWaitTimeoutMilliseconds, true, 4);
            Append(b, "preloadAbandonTimeoutMilliseconds", streaming.PreloadAbandonTimeoutMilliseconds, true, 4);
            Append(b, "fallbackMode", streaming.FallbackMode, false, 4);
            b.AppendLine("  }");
            b.AppendLine("}");
            return b.ToString();
        }

        private void Append(StringBuilder b, string name, string value, bool comma, int indent = 2)
        {
            b.Append(' ', indent).Append('"').Append(name).Append("\": ")
                .Append(serializer.Serialize(value ?? string.Empty));
            b.AppendLine(comma ? "," : string.Empty);
        }

        private static void Append(StringBuilder b, string name, bool value, bool comma, int indent = 2)
        {
            b.Append(' ', indent).Append('"').Append(name).Append("\": ")
                .Append(value ? "true" : "false");
            b.AppendLine(comma ? "," : string.Empty);
        }

        private static void Append(StringBuilder b, string name, int value, bool comma, int indent = 2)
        {
            b.Append(' ', indent).Append('"').Append(name).Append("\": ")
                .Append(value.ToString(CultureInfo.InvariantCulture));
            b.AppendLine(comma ? "," : string.Empty);
        }

        private static void Append(StringBuilder b, string name, double value, bool comma, int indent = 2)
        {
            b.Append(' ', indent).Append('"').Append(name).Append("\": ")
                .Append(value.ToString("0.###", CultureInfo.InvariantCulture));
            b.AppendLine(comma ? "," : string.Empty);
        }
    }
}
