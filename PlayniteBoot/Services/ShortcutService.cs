using System;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Text;
using System.Web.Script.Serialization;

namespace PlayniteBoot.Services
{
    public enum ShortcutLocation
    {
        Desktop,
        StartMenu
    }

    public class ShortcutState
    {
        public string DesktopName { get; set; }
        public string StartMenuName { get; set; }
    }

    public class ShortcutService
    {
        private static readonly string[] ReservedNames =
        {
            "CON", "PRN", "AUX", "NUL",
            "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
            "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
        };

        private readonly RuntimePaths paths;
        private readonly JavaScriptSerializer serializer = new JavaScriptSerializer();

        public ShortcutService(RuntimePaths paths)
        {
            this.paths = paths;
        }

        public string Create(ShortcutLocation location, string shortcutName, string description)
        {
            if (!File.Exists(paths.ShortcutInstallerPath))
            {
                throw new FileNotFoundException("LOCPlayniteBootErrorShortcutInstallerMissing".GetLocalized(), paths.ShortcutInstallerPath);
            }

            var normalizedName = (shortcutName ?? string.Empty).Trim();
            if (!TryGetShortcutPath(location, normalizedName, out var shortcutPath))
            {
                throw new ArgumentException("LOCPlayniteBootValidationShortcutCharacters".GetLocalized(), nameof(shortcutName));
            }

            var state = LoadState();
            var previousName = location == ShortcutLocation.Desktop ? state.DesktopName : state.StartMenuName;
            if (!string.IsNullOrWhiteSpace(previousName) &&
                !string.Equals(previousName, normalizedName, StringComparison.OrdinalIgnoreCase))
            {
                DeleteShortcutFile(location, previousName);
            }

            var switchName = location == ShortcutLocation.Desktop ? "-Desktop" : "-StartMenu";
            var startInfo = new ProcessStartInfo
            {
                FileName = WindowsPowerShell.ExecutablePath,
                Arguments = string.Format(
                    "-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"{0}\" {1}",
                    paths.ShortcutInstallerPath,
                    switchName),
                WorkingDirectory = paths.RuntimeDirectory,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true
            };

            // Pass user-facing strings through Base64 environment variables instead
            // of interpolating them into PowerShell syntax. This keeps shortcut names
            // containing $, apostrophes or other valid filename characters intact.
            startInfo.EnvironmentVariables["PLAYNITEBOOT_SHORTCUT_NAME_B64"] =
                Convert.ToBase64String(Encoding.UTF8.GetBytes(normalizedName));
            startInfo.EnvironmentVariables["PLAYNITEBOOT_SHORTCUT_DESCRIPTION_B64"] =
                Convert.ToBase64String(Encoding.UTF8.GetBytes(description ?? string.Empty));

            using (var process = Process.Start(startInfo))
            {
                if (process == null)
                {
                    throw new InvalidOperationException("LOCPlayniteBootErrorShortcutProcess".GetLocalized());
                }

                var outputTask = process.StandardOutput.ReadToEndAsync();
                var errorTask = process.StandardError.ReadToEndAsync();

                if (!process.WaitForExit(20000))
                {
                    process.Kill();
                    process.WaitForExit();
                    outputTask.GetAwaiter().GetResult();
                    errorTask.GetAwaiter().GetResult();
                    throw new TimeoutException("LOCPlayniteBootErrorShortcutTimeout".GetLocalized());
                }

                var output = outputTask.GetAwaiter().GetResult();
                var error = errorTask.GetAwaiter().GetResult();
                if (process.ExitCode != 0)
                {
                    throw new InvalidOperationException(string.IsNullOrWhiteSpace(error) ? output : error);
                }
            }

            if (location == ShortcutLocation.Desktop)
            {
                state.DesktopName = normalizedName;
            }
            else
            {
                state.StartMenuName = normalizedName;
            }

            SaveState(state);
            return shortcutPath;
        }

        public bool Remove(ShortcutLocation location, string configuredName)
        {
            var state = LoadState();
            var managedName = location == ShortcutLocation.Desktop ? state.DesktopName : state.StartMenuName;
            var removed = false;

            if (!string.IsNullOrWhiteSpace(managedName))
            {
                removed |= DeleteShortcutFile(location, managedName);
            }

            if (!string.IsNullOrWhiteSpace(configuredName) &&
                !string.Equals(configuredName, managedName, StringComparison.OrdinalIgnoreCase))
            {
                removed |= DeleteShortcutFile(location, configuredName.Trim());
            }

            if (location == ShortcutLocation.Desktop)
            {
                state.DesktopName = null;
            }
            else
            {
                state.StartMenuName = null;
            }

            SaveState(state);
            return removed;
        }

        public bool Exists(ShortcutLocation location, string configuredName)
        {
            var state = LoadState();
            var managedName = location == ShortcutLocation.Desktop ? state.DesktopName : state.StartMenuName;
            var name = string.IsNullOrWhiteSpace(managedName) ? configuredName : managedName;
            return TryGetShortcutPath(location, name, out var shortcutPath) && File.Exists(shortcutPath);
        }

        private static bool DeleteShortcutFile(ShortcutLocation location, string shortcutName)
        {
            if (!TryGetShortcutPath(location, shortcutName, out var shortcutPath) || !File.Exists(shortcutPath))
            {
                return false;
            }

            File.Delete(shortcutPath);
            return true;
        }

        private static bool TryGetShortcutPath(ShortcutLocation location, string shortcutName, out string shortcutPath)
        {
            shortcutPath = null;
            var normalizedName = (shortcutName ?? string.Empty).Trim();
            if (!IsValidShortcutName(normalizedName))
            {
                return false;
            }

            var folder = location == ShortcutLocation.Desktop
                ? Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory)
                : Environment.GetFolderPath(Environment.SpecialFolder.Programs);

            if (string.IsNullOrWhiteSpace(folder))
            {
                return false;
            }

            var canonicalFolder = Path.GetFullPath(folder)
                .TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar) + Path.DirectorySeparatorChar;
            var candidatePath = Path.GetFullPath(Path.Combine(canonicalFolder, normalizedName + ".lnk"));

            if (!candidatePath.StartsWith(canonicalFolder, StringComparison.OrdinalIgnoreCase))
            {
                return false;
            }

            shortcutPath = candidatePath;
            return true;
        }

        private static bool IsValidShortcutName(string shortcutName)
        {
            if (string.IsNullOrWhiteSpace(shortcutName) || shortcutName.Length > 120)
            {
                return false;
            }

            if (Path.IsPathRooted(shortcutName) ||
                !string.Equals(Path.GetFileName(shortcutName), shortcutName, StringComparison.Ordinal) ||
                shortcutName.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 ||
                shortcutName.EndsWith(".", StringComparison.Ordinal) ||
                shortcutName.EndsWith(" ", StringComparison.Ordinal))
            {
                return false;
            }

            var baseName = shortcutName.Split('.')[0].ToUpperInvariant();
            return !ReservedNames.Contains(baseName, StringComparer.OrdinalIgnoreCase);
        }

        private ShortcutState LoadState()
        {
            try
            {
                if (!File.Exists(paths.ShortcutStatePath))
                {
                    return new ShortcutState();
                }

                var json = File.ReadAllText(paths.ShortcutStatePath, Encoding.UTF8);
                return serializer.Deserialize<ShortcutState>(json) ?? new ShortcutState();
            }
            catch
            {
                return new ShortcutState();
            }
        }

        private void SaveState(ShortcutState state)
        {
            Directory.CreateDirectory(paths.PluginDataPath);
            var temp = paths.ShortcutStatePath + ".tmp";

            try
            {
                File.WriteAllText(temp, serializer.Serialize(state), new UTF8Encoding(false));

                if (File.Exists(paths.ShortcutStatePath))
                {
                    var backup = paths.ShortcutStatePath + ".bak";
                    if (File.Exists(backup))
                    {
                        File.Delete(backup);
                    }

                    File.Replace(temp, paths.ShortcutStatePath, backup, true);
                    if (File.Exists(backup))
                    {
                        File.Delete(backup);
                    }
                }
                else
                {
                    File.Move(temp, paths.ShortcutStatePath);
                }
            }
            finally
            {
                try
                {
                    if (File.Exists(temp))
                    {
                        File.Delete(temp);
                    }
                }
                catch
                {
                    // Preserve the original save result or exception.
                }
            }
        }
    }
}
