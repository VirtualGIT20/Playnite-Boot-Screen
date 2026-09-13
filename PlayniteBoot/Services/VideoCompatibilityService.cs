
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;

namespace PlayniteBoot.Services
{
    public sealed class VideoCompatibilityResult
    {
        public VideoCompatibilityResult(string playbackPath, string strategy, bool cacheCreated, string warning)
        {
            PlaybackPath = playbackPath;
            Strategy = strategy;
            CacheCreated = cacheCreated;
            Warning = warning;
        }

        public string PlaybackPath { get; }
        public string Strategy { get; }
        public bool CacheCreated { get; }
        public string Warning { get; }
    }

    public class VideoCompatibilityService
    {
        public const string DirectStrategy = "direct";
        public const string CachedStrategy = "cache";
        public const string HardLinkStrategy = "hardlink";
        public const string CopyStrategy = "copy";

        private readonly RuntimePaths paths;

        public VideoCompatibilityService(RuntimePaths paths)
        {
            this.paths = paths;
        }

        public VideoCompatibilityResult Resolve(string sourcePath)
        {
            if (string.IsNullOrWhiteSpace(sourcePath))
            {
                return Direct(sourcePath);
            }

            string fullSourcePath;
            try
            {
                fullSourcePath = Path.GetFullPath(sourcePath);
            }
            catch (Exception exception) when (IsExpectedPathException(exception))
            {
                return Direct(sourcePath);
            }

            if (!string.Equals(Path.GetExtension(fullSourcePath), ".webm", StringComparison.OrdinalIgnoreCase))
            {
                CleanupUnusedSourceDirectories(null);
                return Direct(fullSourcePath);
            }

            if (!File.Exists(fullSourcePath))
            {
                return Direct(fullSourcePath);
            }

            try
            {
                var sourceInfo = new FileInfo(fullSourcePath);
                sourceInfo.Refresh();

                var sourceDirectory = Path.Combine(
                    paths.VideoCompatibilityCacheDirectory,
                    GetStablePathHash(fullSourcePath));
                var aliasFileName = string.Format(
                    "{0}-{1}.mkv",
                    sourceInfo.Length,
                    sourceInfo.LastWriteTimeUtc.Ticks);
                var aliasPath = Path.Combine(sourceDirectory, aliasFileName);

                Directory.CreateDirectory(sourceDirectory);

                if (IsValidAlias(aliasPath, sourceInfo))
                {
                    CleanupStaleAliases(sourceDirectory, aliasPath);
                    CleanupUnusedSourceDirectories(sourceDirectory);
                    return new VideoCompatibilityResult(aliasPath, CachedStrategy, false, null);
                }

                TryDelete(aliasPath);

                if (TryCreateHardLink(aliasPath, fullSourcePath) && IsValidAlias(aliasPath, sourceInfo))
                {
                    CleanupStaleAliases(sourceDirectory, aliasPath);
                    CleanupUnusedSourceDirectories(sourceDirectory);
                    return new VideoCompatibilityResult(aliasPath, HardLinkStrategy, true, null);
                }

                TryDelete(aliasPath);
                CopyAtomically(fullSourcePath, aliasPath, sourceInfo.LastWriteTimeUtc);

                if (!IsValidAlias(aliasPath, sourceInfo))
                {
                    throw new IOException("The compatibility cache copy could not be verified.");
                }

                CleanupStaleAliases(sourceDirectory, aliasPath);
                CleanupUnusedSourceDirectories(sourceDirectory);
                return new VideoCompatibilityResult(aliasPath, CopyStrategy, true, null);
            }
            catch (Exception exception) when (IsExpectedCompatibilityException(exception))
            {
                return new VideoCompatibilityResult(
                    fullSourcePath,
                    DirectStrategy,
                    false,
                    exception.Message);
            }
        }

        private static VideoCompatibilityResult Direct(string sourcePath)
        {
            return new VideoCompatibilityResult(sourcePath, DirectStrategy, false, null);
        }

        private static bool IsValidAlias(string aliasPath, FileInfo sourceInfo)
        {
            if (!File.Exists(aliasPath))
            {
                return false;
            }

            try
            {
                var aliasInfo = new FileInfo(aliasPath);
                aliasInfo.Refresh();
                return aliasInfo.Length == sourceInfo.Length &&
                    aliasInfo.LastWriteTimeUtc == sourceInfo.LastWriteTimeUtc;
            }
            catch (Exception exception) when (IsExpectedCompatibilityException(exception))
            {
                return false;
            }
        }

        private static string GetStablePathHash(string sourcePath)
        {
            var normalizedPath = Path.GetFullPath(sourcePath)
                .Trim()
                .Replace(Path.AltDirectorySeparatorChar, Path.DirectorySeparatorChar)
                .ToUpperInvariant();

            using (var sha256 = SHA256.Create())
            {
                var bytes = Encoding.UTF8.GetBytes(normalizedPath);
                var hash = sha256.ComputeHash(bytes);
                var builder = new StringBuilder(hash.Length * 2);
                foreach (var value in hash)
                {
                    builder.Append(value.ToString("x2"));
                }

                return builder.ToString();
            }
        }

        private static void CopyAtomically(string sourcePath, string aliasPath, DateTime sourceLastWriteTimeUtc)
        {
            var tempPath = aliasPath + ".tmp-" + Guid.NewGuid().ToString("N");
            try
            {
                File.Copy(sourcePath, tempPath, false);
                File.SetLastWriteTimeUtc(tempPath, sourceLastWriteTimeUtc);
                File.Move(tempPath, aliasPath);
            }
            finally
            {
                TryDelete(tempPath);
            }
        }

        private static void CleanupStaleAliases(string directoryPath, string currentAliasPath)
        {
            try
            {
                foreach (var path in Directory.EnumerateFiles(directoryPath, "*.mkv", SearchOption.TopDirectoryOnly))
                {
                    if (!string.Equals(path, currentAliasPath, StringComparison.OrdinalIgnoreCase))
                    {
                        TryDelete(path);
                    }
                }

                foreach (var path in Directory.EnumerateFiles(directoryPath, "*.tmp-*", SearchOption.TopDirectoryOnly))
                {
                    TryDelete(path);
                }
            }
            catch (Exception exception) when (IsExpectedCompatibilityException(exception))
            {
                // Cache cleanup is best effort and must never block playback.
            }
        }

        private void CleanupUnusedSourceDirectories(string currentSourceDirectory)
        {
            try
            {
                if (!Directory.Exists(paths.VideoCompatibilityCacheDirectory))
                {
                    return;
                }

                foreach (var directoryPath in Directory.EnumerateDirectories(
                    paths.VideoCompatibilityCacheDirectory,
                    "*",
                    SearchOption.TopDirectoryOnly))
                {
                    if (!string.IsNullOrWhiteSpace(currentSourceDirectory) &&
                        string.Equals(directoryPath, currentSourceDirectory, StringComparison.OrdinalIgnoreCase))
                    {
                        continue;
                    }

                    TryDeleteDirectory(directoryPath);
                }

                TryDeleteDirectoryIfEmpty(paths.VideoCompatibilityCacheDirectory);
                TryDeleteDirectoryIfEmpty(Path.GetDirectoryName(paths.VideoCompatibilityCacheDirectory));
            }
            catch (Exception exception) when (IsExpectedCompatibilityException(exception))
            {
                // Cache cleanup is best effort and must never block playback.
            }
        }

        private static void TryDeleteDirectory(string directoryPath)
        {
            if (string.IsNullOrWhiteSpace(directoryPath) || !Directory.Exists(directoryPath))
            {
                return;
            }

            try
            {
                Directory.Delete(directoryPath, true);
            }
            catch (Exception exception) when (IsExpectedCompatibilityException(exception))
            {
                // An in-use cache entry can be retried the next time configuration is written.
            }
        }

        private static void TryDeleteDirectoryIfEmpty(string directoryPath)
        {
            if (string.IsNullOrWhiteSpace(directoryPath) || !Directory.Exists(directoryPath))
            {
                return;
            }

            try
            {
                if (Directory.GetFileSystemEntries(directoryPath).Length == 0)
                {
                    Directory.Delete(directoryPath, false);
                }
            }
            catch (Exception exception) when (IsExpectedCompatibilityException(exception))
            {
                // Cache cleanup is best effort and must never block playback.
            }
        }

        private static void TryDelete(string path)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                return;
            }

            try
            {
                if (File.Exists(path))
                {
                    File.Delete(path);
                }
            }
            catch (Exception exception) when (IsExpectedCompatibilityException(exception))
            {
                // A stale or in-use cache entry can be retried on a later run.
            }
        }

        private static bool IsExpectedPathException(Exception exception)
        {
            return exception is ArgumentException ||
                exception is NotSupportedException ||
                exception is PathTooLongException;
        }

        private static bool IsExpectedCompatibilityException(Exception exception)
        {
            return IsExpectedPathException(exception) ||
                exception is IOException ||
                exception is UnauthorizedAccessException ||
                exception is System.Security.SecurityException;
        }

        private static bool TryCreateHardLink(string aliasPath, string sourcePath)
        {
            try
            {
                return CreateHardLink(aliasPath, sourcePath, IntPtr.Zero);
            }
            catch (DllNotFoundException)
            {
                return false;
            }
            catch (EntryPointNotFoundException)
            {
                return false;
            }
        }

        [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CreateHardLink(
            string fileName,
            string existingFileName,
            IntPtr securityAttributes);
    }
}
