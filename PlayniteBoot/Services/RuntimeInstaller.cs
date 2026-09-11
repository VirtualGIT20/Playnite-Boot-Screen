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
            "SwitchBootstrap.ps1",
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
            var sourceVersion = File.Exists(sourceVersionPath) ? File.ReadAllText(sourceVersionPath).Trim() : "unknown";
            var copied = 0;

            // VERSION.txt is diagnostic metadata, not the update trigger. Compare
            // each managed file by content so a runtime change is synchronized even
            // if the runtime version was accidentally left unchanged.
            foreach (var relativePath in ManagedFiles)
            {
                var source = Path.Combine(paths.RuntimeTemplateDirectory, relativePath);
                var target = Path.Combine(paths.RuntimeDirectory, relativePath);
                if (!File.Exists(source))
                {
                    continue;
                }

                if (force || !File.Exists(target) || !FilesHaveSameContent(source, target))
                {
                    var targetDirectory = Path.GetDirectoryName(target);
                    if (!string.IsNullOrWhiteSpace(targetDirectory))
                    {
                        Directory.CreateDirectory(targetDirectory);
                    }

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

        private static bool FilesHaveSameContent(string firstPath, string secondPath)
        {
            var firstInfo = new FileInfo(firstPath);
            var secondInfo = new FileInfo(secondPath);
            if (firstInfo.Length != secondInfo.Length)
            {
                return false;
            }

            const int bufferSize = 81920;
            var firstBuffer = new byte[bufferSize];
            var secondBuffer = new byte[bufferSize];

            using (var firstStream = new FileStream(firstPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
            using (var secondStream = new FileStream(secondPath, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
            {
                while (true)
                {
                    var firstRead = firstStream.Read(firstBuffer, 0, firstBuffer.Length);
                    var secondRead = secondStream.Read(secondBuffer, 0, secondBuffer.Length);
                    if (firstRead != secondRead)
                    {
                        return false;
                    }

                    if (firstRead == 0)
                    {
                        return true;
                    }

                    for (var index = 0; index < firstRead; index++)
                    {
                        if (firstBuffer[index] != secondBuffer[index])
                        {
                            return false;
                        }
                    }
                }
            }
        }
    }
}
