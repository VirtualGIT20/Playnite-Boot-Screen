using System;
using System.Diagnostics;
using System.IO;
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

            var normalizedName = shortcutName.Trim();
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
                FileName = "powershell.exe",
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

                if (!process.WaitForExit(20000))
                {
                    process.Kill();
                    throw new TimeoutException("LOCPlayniteBootErrorShortcutTimeout".GetLocalized());
                }

                var output = process.StandardOutput.ReadToEnd();
                var error = process.StandardError.ReadToEnd();
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
            return GetShortcutPath(location, normalizedName);
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
            return !string.IsNullOrWhiteSpace(name) && File.Exists(GetShortcutPath(location, name.Trim()));
        }

        private bool DeleteShortcutFile(ShortcutLocation location, string shortcutName)
        {
            var path = GetShortcutPath(location, shortcutName.Trim());
            if (!File.Exists(path))
            {
                return false;
            }

            File.Delete(path);
            return true;
        }

        private static string GetShortcutPath(ShortcutLocation location, string shortcutName)
        {
            var folder = location == ShortcutLocation.Desktop
                ? Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory)
                : Environment.GetFolderPath(Environment.SpecialFolder.Programs);

            return Path.Combine(folder, shortcutName + ".lnk");
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

    }
}
