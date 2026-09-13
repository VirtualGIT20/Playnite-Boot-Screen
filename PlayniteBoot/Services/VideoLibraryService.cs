using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace PlayniteBoot.Services
{
    public class VideoLibraryService
    {
        private static readonly string[] AcceptedExtensionList =
        {
            ".mp4",
            ".mkv",
            ".webm",
            ".avi",
            ".mov"
        };

        private static readonly HashSet<string> AcceptedExtensions = new HashSet<string>(
            AcceptedExtensionList,
            StringComparer.OrdinalIgnoreCase);

        private readonly RuntimePaths paths;

        public VideoLibraryService(RuntimePaths paths)
        {
            this.paths = paths;
        }

        public static string AcceptedFormatsDisplay => string.Join(", ", AcceptedExtensionList.Select(extension =>
            string.Equals(extension, ".webm", StringComparison.OrdinalIgnoreCase)
                ? "WebM"
                : extension.Substring(1).ToUpperInvariant()));

        public static string AcceptedFormatsWildcard => string.Join(";", AcceptedExtensionList.Select(extension => "*" + extension));

        public static string BuildFileDialogFilter(string videoFilesLabel)
        {
            return string.Format("{0}|{1}", videoFilesLabel, AcceptedFormatsWildcard);
        }

        public IReadOnlyList<string> GetLibraryVideos()
        {
            Directory.CreateDirectory(paths.MediaDirectory);

            return Directory
                .EnumerateFiles(paths.MediaDirectory, "*", SearchOption.TopDirectoryOnly)
                .Where(IsAcceptedVideo)
                .Select(Path.GetFullPath)
                .OrderBy(Path.GetFileName, StringComparer.CurrentCultureIgnoreCase)
                .ToList();
        }

        public static bool IsAcceptedVideo(string filePath)
        {
            return !string.IsNullOrWhiteSpace(filePath) &&
                AcceptedExtensions.Contains(Path.GetExtension(filePath));
        }

        // Compatibility alias for callers compiled against the previous name.
        public static bool IsSupportedVideo(string filePath)
        {
            return IsAcceptedVideo(filePath);
        }
    }
}
