using System;
using System.Collections.Generic;
using System.IO;

namespace PlayniteBoot.Services
{
    public class RuntimeInstallResult
    {
        public bool Updated { get; set; }
        public string Version { get; set; }
        public int CopiedFiles { get; set; }
    }

    public class RuntimeInstaller
    {
        private static readonly string[] ManagedFiles =
        {
            "PlayniteBoot.ps1",
            "Launch-PlayniteBoot.vbs",
            "Install-Shortcut.ps1",
            "Test-Configuration.ps1",
            "VERSION.txt"
        };

        private readonly RuntimePaths paths;

        public RuntimeInstaller(RuntimePaths paths)
        {
            this.paths = paths;
        }

        public RuntimeInstallResult EnsureInstalled(bool force = false)
        {
            if (!Directory.Exists(paths.RuntimeTemplateDirectory))
            {
                throw new DirectoryNotFoundException(string.Format("LOCPlayniteBootErrorRuntimeTemplateMissing".GetLocalized(), paths.RuntimeTemplateDirectory));
            }

            Directory.CreateDirectory(paths.RuntimeDirectory);
            Directory.CreateDirectory(paths.MediaDirectory);
            Directory.CreateDirectory(paths.LogsDirectory);

            var sourceVersionPath = Path.Combine(paths.RuntimeTemplateDirectory, "VERSION.txt");
            var targetVersionPath = Path.Combine(paths.RuntimeDirectory, "VERSION.txt");
            var sourceVersion = File.Exists(sourceVersionPath) ? File.ReadAllText(sourceVersionPath).Trim() : "unknown";
            var targetVersion = File.Exists(targetVersionPath) ? File.ReadAllText(targetVersionPath).Trim() : string.Empty;
            var updateManagedFiles = force || !string.Equals(sourceVersion, targetVersion, StringComparison.OrdinalIgnoreCase);
            var copied = 0;

            foreach (var relativePath in ManagedFiles)
            {
                var source = Path.Combine(paths.RuntimeTemplateDirectory, relativePath);
                var target = Path.Combine(paths.RuntimeDirectory, relativePath);
                if (File.Exists(source) && (updateManagedFiles || !File.Exists(target)))
                {
                    File.Copy(source, target, true);
                    copied++;
                }
            }

            // A customized default video must survive extension updates.
            var sourceVideo = Path.Combine(paths.RuntimeTemplateDirectory, "media", "boot-4k60.mp4");
            if (File.Exists(sourceVideo) && !File.Exists(paths.DefaultVideoPath))
            {
                File.Copy(sourceVideo, paths.DefaultVideoPath, false);
                copied++;
            }

            return new RuntimeInstallResult
            {
                Updated = copied > 0,
                Version = sourceVersion,
                CopiedFiles = copied
            };
        }
    }
}
