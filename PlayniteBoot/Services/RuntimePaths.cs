using System.IO;

namespace PlayniteBoot.Services
{
    public class RuntimePaths
    {
        public RuntimePaths(string pluginDataPath, string extensionInstallPath)
        {
            PluginDataPath = pluginDataPath;
            ExtensionInstallPath = extensionInstallPath;
            RuntimeTemplateDirectory = Path.Combine(extensionInstallPath, "RuntimeTemplate");
            RuntimeDirectory = Path.Combine(pluginDataPath, "Runtime");
            MediaDirectory = Path.Combine(RuntimeDirectory, "media");
            LogsDirectory = Path.Combine(RuntimeDirectory, "logs");
            ConfigPath = Path.Combine(RuntimeDirectory, "config.json");
            ScriptPath = Path.Combine(RuntimeDirectory, "PlayniteBoot.ps1");
            ShortcutInstallerPath = Path.Combine(RuntimeDirectory, "Install-Shortcut.ps1");
            ShortcutStatePath = Path.Combine(pluginDataPath, "shortcut-state.json");
            DefaultTemplateVideoPath = Path.Combine(RuntimeTemplateDirectory, "media", "boot-4k60.mp4");
            DefaultVideoPath = Path.Combine(MediaDirectory, "boot-4k60.mp4");
            LogPath = Path.Combine(LogsDirectory, "PlayniteBoot.log");
        }

        public string PluginDataPath { get; }
        public string ExtensionInstallPath { get; }
        public string RuntimeTemplateDirectory { get; }
        public string RuntimeDirectory { get; }
        public string MediaDirectory { get; }
        public string LogsDirectory { get; }
        public string ConfigPath { get; }
        public string ScriptPath { get; }
        public string ShortcutInstallerPath { get; }
        public string ShortcutStatePath { get; }
        public string DefaultTemplateVideoPath { get; }
        public string DefaultVideoPath { get; }
        public string LogPath { get; }
    }
}
