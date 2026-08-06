using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace PlayniteBoot.Services
{
    public class VideoLibraryService
    {
        private static readonly HashSet<string> SupportedExtensions = new HashSet<string>(
            new[] { ".mp4", ".mkv", ".webm", ".avi", ".mov" },
            StringComparer.OrdinalIgnoreCase);

        private readonly RuntimePaths paths;

        public VideoLibraryService(RuntimePaths paths)
        {
            this.paths = paths;
        }

        public IReadOnlyList<string> GetLibraryVideos()
        {
            Directory.CreateDirectory(paths.MediaDirectory);

            return Directory
                .EnumerateFiles(paths.MediaDirectory, "*", SearchOption.TopDirectoryOnly)
                .Where(IsSupportedVideo)
                .Select(Path.GetFullPath)
                .OrderBy(Path.GetFileName, StringComparer.CurrentCultureIgnoreCase)
                .ToList();
        }

        public static bool IsSupportedVideo(string filePath)
        {
            return !string.IsNullOrWhiteSpace(filePath) &&
                SupportedExtensions.Contains(Path.GetExtension(filePath));
        }
    }
}
