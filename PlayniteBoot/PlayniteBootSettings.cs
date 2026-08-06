using Playnite.SDK;
using Playnite.SDK.Data;
using PlayniteBoot.Models;
using PlayniteBoot.Services;
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Windows;
using Forms = System.Windows.Forms;

namespace PlayniteBoot
{
    public class PlayniteBootSettingsViewModel : ObservableObject, ISettings
    {
        private readonly PlayniteBootPlugin plugin;
        private readonly VideoLibraryService videoLibrary;
        private PlayniteBootSettingsData editingClone;
        private PlayniteBootSettingsData settings;
        private string runtimeStatus;
        private bool synchronizingVideoOptions;

        public PlayniteBootSettingsData Settings
        {
            get => settings;
            set
            {
                if (settings != null)
                {
                    settings.PropertyChanged -= SettingsPropertyChanged;
                }

                settings = value;
                EnsureDefaultsAndMigrate();
                settings.PropertyChanged += SettingsPropertyChanged;

                OnPropertyChanged();
                OnPropertyChanged(nameof(DirectCommand));
                OnPropertyChanged(nameof(PreloadCommand));
                OnPropertyChanged(nameof(ContinueCommand));
                OnPropertyChanged(nameof(IsLoopVideoEnabled));
                OnPropertyChanged(nameof(IsMinimumVideoDurationEnabled));
                OnPropertyChanged(nameof(IsVolumeEnabled));
                OnPropertyChanged(nameof(VolumePercent));
                OnPropertyChanged(nameof(SelectedVideoPath));
                OnPropertyChanged(nameof(SelectedVideoPathDisplay));

                if (videoLibrary != null)
                {
                    RefreshVideoLibrary(false);
                }
            }
        }

        public string RuntimeStatus
        {
            get => runtimeStatus;
            private set => SetValue(ref runtimeStatus, value);
        }

        public ObservableCollection<VideoOption> VideoOptions { get; } = new ObservableCollection<VideoOption>();

        public string SelectedVideoPath
        {
            get => Settings == null ? string.Empty : GetConfiguredVideoPath();
            set
            {
                if (Settings == null || string.IsNullOrWhiteSpace(value) ||
                    PathsEqual(Settings.VideoPath, value))
                {
                    return;
                }

                Settings.VideoPath = Path.GetFullPath(value);
                OnPropertyChanged();
                OnPropertyChanged(nameof(SelectedVideoPathDisplay));
            }
        }

        public string SelectedVideoPathDisplay => Settings == null
            ? string.Empty
            : GetConfiguredVideoPath();

        public bool IsLoopVideoEnabled => Settings == null || !Settings.WaitForVideoEnd;
        public bool IsMinimumVideoDurationEnabled => Settings == null || !Settings.WaitForVideoEnd;
        public bool IsVolumeEnabled => Settings == null || !Settings.Mute;

        public int VolumePercent
        {
            get => Settings == null
                ? 100
                : (int)Math.Round(Settings.Volume * 100.0, 0, MidpointRounding.AwayFromZero);
            set
            {
                if (Settings == null)
                {
                    return;
                }

                var clamped = Math.Max(0, Math.Min(100, value));
                Settings.Volume = clamped / 100.0;
                OnPropertyChanged();
            }
        }

        public string RuntimeDirectory => plugin.Paths.RuntimeDirectory;
        public string DirectCommand => plugin.Commands.DirectCommand;
        public string PreloadCommand => plugin.Commands.PreloadCommand;
        public string ContinueCommand => plugin.Commands.ContinueCommand;

        public List<LocalizedOption> GeneralMonitorOptions { get; }
        public List<LocalizedOption> StreamingMonitorOptions { get; }
        public List<LocalizedOption> VideoStretchOptions { get; }
        public List<LocalizedOption> FallbackOptions { get; }

        public RelayCommand BrowseVideoCommand { get; }
        public RelayCommand RefreshVideoLibraryCommand { get; }
        public RelayCommand OpenVideoFolderCommand { get; }
        public RelayCommand RestoreDefaultVideoCommand { get; }
        public RelayCommand ResetSettingsCommand { get; }
        public RelayCommand InstallRuntimeCommand { get; }
        public RelayCommand CreateDesktopShortcutCommand { get; }
        public RelayCommand CreateStartMenuShortcutCommand { get; }
        public RelayCommand RemoveDesktopShortcutCommand { get; }
        public RelayCommand RemoveStartMenuShortcutCommand { get; }
        public RelayCommand CopyDirectCommand { get; }
        public RelayCommand CopyPreloadCommand { get; }
        public RelayCommand CopyContinueCommand { get; }
        public RelayCommand CopyDiagnosticsCommand { get; }
        public RelayCommand OpenRuntimeFolderCommand { get; }
        public RelayCommand OpenLogsFolderCommand { get; }

        public PlayniteBootSettingsViewModel(PlayniteBootPlugin plugin)
        {
            this.plugin = plugin;
            videoLibrary = new VideoLibraryService(plugin.Paths);
            Settings = plugin.LoadPluginSettings<PlayniteBootSettingsData>() ?? PlayniteBootSettingsData.CreateDefault();

            GeneralMonitorOptions = BuildMonitorOptions(false);
            StreamingMonitorOptions = BuildMonitorOptions(true);
            EnsureMonitorOptionPresent(GeneralMonitorOptions, Settings.Monitor);
            EnsureMonitorOptionPresent(StreamingMonitorOptions, Settings.Streaming.Monitor);
            VideoStretchOptions = new List<LocalizedOption>
            {
                new LocalizedOption("UniformToFill", L("LOCPlayniteBootOptionStretchFillCrop")),
                new LocalizedOption("Uniform", L("LOCPlayniteBootOptionStretchFit")),
                new LocalizedOption("Fill", L("LOCPlayniteBootOptionStretchStretch"))
            };
            FallbackOptions = new List<LocalizedOption>
            {
                new LocalizedOption("standalone", L("LOCPlayniteBootOptionFallbackStandalone"))
            };

            BrowseVideoCommand = new RelayCommand(BrowseVideo);
            RefreshVideoLibraryCommand = new RelayCommand(() => RefreshVideoLibrary(true));
            OpenVideoFolderCommand = new RelayCommand(() => ExecuteAction(OpenVideoFolder));
            RestoreDefaultVideoCommand = new RelayCommand(RestoreDefaultVideo);
            ResetSettingsCommand = new RelayCommand(ResetSettings);
            InstallRuntimeCommand = new RelayCommand(() => ExecuteAction(InstallRuntime));
            CreateDesktopShortcutCommand = new RelayCommand(() => ExecuteAction(() => CreateShortcut(ShortcutLocation.Desktop)));
            CreateStartMenuShortcutCommand = new RelayCommand(() => ExecuteAction(() => CreateShortcut(ShortcutLocation.StartMenu)));
            RemoveDesktopShortcutCommand = new RelayCommand(() => ExecuteAction(() => RemoveShortcut(ShortcutLocation.Desktop)));
            RemoveStartMenuShortcutCommand = new RelayCommand(() => ExecuteAction(() => RemoveShortcut(ShortcutLocation.StartMenu)));
            CopyDirectCommand = new RelayCommand(() => CopyToClipboard(DirectCommand));
            CopyPreloadCommand = new RelayCommand(() => CopyToClipboard(PreloadCommand));
            CopyContinueCommand = new RelayCommand(() => CopyToClipboard(ContinueCommand));
            CopyDiagnosticsCommand = new RelayCommand(CopyDiagnostics);
            OpenRuntimeFolderCommand = new RelayCommand(() => ExecuteAction(() => ShellService.OpenFolder(plugin.Paths.RuntimeDirectory)));
            OpenLogsFolderCommand = new RelayCommand(() => ExecuteAction(() => ShellService.OpenFolder(plugin.Paths.LogsDirectory)));

            RefreshVideoLibrary(false);
            RefreshRuntimeStatus();
        }

        public void BeginEdit()
        {
            editingClone = Serialization.GetClone(Settings);
            RefreshVideoLibrary(false);
            RefreshRuntimeStatus();
        }

        public void CancelEdit()
        {
            Settings = editingClone ?? PlayniteBootSettingsData.CreateDefault();
            RefreshRuntimeStatus();
        }

        public void EndEdit()
        {
            Settings.SettingsVersion = PlayniteBootSettingsData.CurrentSettingsVersion;
            Settings.ShortcutName = (Settings.ShortcutName ?? string.Empty).Trim();
            if (IsManualMonitorSelection(Settings.Monitor))
            {
                Settings.MonitorFallback = Settings.Monitor;
            }
            plugin.SavePluginSettings(Settings);
            plugin.PrepareRuntime(Settings, false);
            RefreshRuntimeStatus();
        }

        public bool VerifySettings(out List<string> errors)
        {
            errors = new List<string>();

            try
            {
                var videoPath = string.IsNullOrWhiteSpace(Settings.VideoPath)
                    ? plugin.Paths.DefaultVideoPath
                    : Path.GetFullPath(Settings.VideoPath);
                var isBundledDefault = string.Equals(
                    videoPath,
                    Path.GetFullPath(plugin.Paths.DefaultVideoPath),
                    StringComparison.OrdinalIgnoreCase);
                if (!File.Exists(videoPath) && !(isBundledDefault && File.Exists(plugin.Paths.DefaultTemplateVideoPath)))
                {
                    errors.Add(F("LOCPlayniteBootValidationVideoMissing", videoPath));
                }
            }
            catch (Exception)
            {
                errors.Add(L("LOCPlayniteBootValidationVideoPath"));
            }

            if (VolumePercent < 0 || VolumePercent > 100 || Settings.Volume < 0 || Settings.Volume > 1)
            {
                errors.Add(L("LOCPlayniteBootValidationVolume"));
            }

            ValidateNonNegative(errors, Settings.MinimumVideoMilliseconds, L("LOCPlayniteBootLabelMinimumDuration"));
            ValidateNonNegative(errors, Settings.ReadyStabilityMilliseconds, L("LOCPlayniteBootLabelReadyStability"));
            ValidatePositive(errors, Settings.StartTimeoutSeconds, L("LOCPlayniteBootLabelStartTimeout"));
            ValidateNonNegative(errors, Settings.VideoReadyPositionMilliseconds, L("LOCPlayniteBootLabelVideoReadyPosition"));
            ValidatePositive(errors, Settings.VideoReadyAdvanceSamples, L("LOCPlayniteBootLabelVideoReadySamples"));
            ValidateMinimum(errors, Settings.VideoReadyTimeoutMilliseconds, 1000, L("LOCPlayniteBootLabelVideoReadyTimeout"));
            ValidateNonNegative(errors, Settings.FadeInMilliseconds, L("LOCPlayniteBootLabelFadeIn"));
            ValidateNonNegative(errors, Settings.FadeOutMilliseconds, L("LOCPlayniteBootLabelFadeOut"));

            if (Settings.Streaming == null)
            {
                errors.Add(L("LOCPlayniteBootValidationStreaming"));
            }
            else
            {
                ValidateMinimum(errors, Settings.Streaming.PreloadReadyTimeoutMilliseconds, 1000, L("LOCPlayniteBootLabelPreloadReadyTimeout"));
                ValidateMinimum(errors, Settings.Streaming.ContinueWaitTimeoutMilliseconds, 1000, L("LOCPlayniteBootLabelContinueTimeout"));
                ValidateMinimum(errors, Settings.Streaming.PreloadAbandonTimeoutMilliseconds, 5000, L("LOCPlayniteBootLabelPreloadAbandonTimeout"));
            }

            if (Settings.WaitForVideoEnd && Settings.LoopVideo)
            {
                errors.Add(L("LOCPlayniteBootValidationLoopWaitConflict"));
            }

            ValidateShortcutName(errors, Settings.ShortcutName);
            return errors.Count == 0;
        }

        private void SettingsPropertyChanged(object sender, PropertyChangedEventArgs eventArgs)
        {
            if (eventArgs.PropertyName == nameof(PlayniteBootSettingsData.VideoPath))
            {
                OnPropertyChanged(nameof(SelectedVideoPath));
                OnPropertyChanged(nameof(SelectedVideoPathDisplay));
                return;
            }

            if (eventArgs.PropertyName == nameof(PlayniteBootSettingsData.Monitor))
            {
                if (IsManualMonitorSelection(Settings.Monitor))
                {
                    Settings.MonitorFallback = Settings.Monitor;
                }

                return;
            }

            if (eventArgs.PropertyName == nameof(PlayniteBootSettingsData.Mute))
            {
                OnPropertyChanged(nameof(IsVolumeEnabled));
                return;
            }

            if (eventArgs.PropertyName == nameof(PlayniteBootSettingsData.Volume))
            {
                OnPropertyChanged(nameof(VolumePercent));
                return;
            }

            if (synchronizingVideoOptions || eventArgs.PropertyName != nameof(PlayniteBootSettingsData.WaitForVideoEnd))
            {
                return;
            }

            if (Settings.WaitForVideoEnd && Settings.LoopVideo)
            {
                try
                {
                    synchronizingVideoOptions = true;
                    Settings.LoopVideo = false;
                }
                finally
                {
                    synchronizingVideoOptions = false;
                }
            }

            OnPropertyChanged(nameof(IsLoopVideoEnabled));
            OnPropertyChanged(nameof(IsMinimumVideoDurationEnabled));
        }

        private void EnsureDefaultsAndMigrate()
        {
            if (settings == null)
            {
                settings = PlayniteBootSettingsData.CreateDefault();
            }

            if (settings.Streaming == null)
            {
                settings.Streaming = new StreamingSettings();
            }

            if (settings.SettingsVersion < 1)
            {
                // M2 stored mute=true and volume=0 by default. Preserve explicit
                // unmuted silence, but make the first unmute useful for old users.
                if (settings.Mute && settings.Volume <= 0)
                {
                    settings.Volume = 1.0;
                }
            }

            if (settings.SettingsVersion < 2 && IsManualMonitorSelection(settings.Monitor))
            {
                // Preserve the user's previous monitor choice as the fallback if
                // Follow Playnite is selected later.
                settings.MonitorFallback = settings.Monitor;
            }

            settings.SettingsVersion = PlayniteBootSettingsData.CurrentSettingsVersion;

            if (string.IsNullOrWhiteSpace(settings.VideoPath))
            {
                settings.VideoPath = plugin.Paths.DefaultVideoPath;
            }

            if (string.IsNullOrWhiteSpace(settings.PlayniteExecutable))
            {
                settings.PlayniteExecutable = "auto";
            }

            if (string.IsNullOrWhiteSpace(settings.LaunchArguments))
            {
                settings.LaunchArguments = "--hidesplashscreen";
            }

            if (string.IsNullOrWhiteSpace(settings.Monitor))
            {
                settings.Monitor = "playnite";
            }
            else if (string.Equals(settings.Monitor, "cursor", StringComparison.OrdinalIgnoreCase))
            {
                settings.Monitor = "auto";
            }

            if (!IsManualMonitorSelection(settings.MonitorFallback))
            {
                settings.MonitorFallback = "primary";
            }

            if (string.IsNullOrWhiteSpace(settings.Streaming.Monitor))
            {
                settings.Streaming.Monitor = "clientResolution";
            }
            else if (string.Equals(settings.Streaming.Monitor, "client", StringComparison.OrdinalIgnoreCase))
            {
                settings.Streaming.Monitor = "clientResolution";
            }
            else if (string.Equals(settings.Streaming.Monitor, "cursor", StringComparison.OrdinalIgnoreCase))
            {
                settings.Streaming.Monitor = "auto";
            }

            if (string.IsNullOrWhiteSpace(settings.VideoStretch))
            {
                settings.VideoStretch = "UniformToFill";
            }

            if (string.IsNullOrWhiteSpace(settings.ShortcutName))
            {
                settings.ShortcutName = "Playnite Fullscreen";
            }

            if (string.IsNullOrWhiteSpace(settings.Streaming.FallbackMode))
            {
                settings.Streaming.FallbackMode = "standalone";
            }
        }

        private static void EnsureMonitorOptionPresent(List<LocalizedOption> options, string value)
        {
            if (string.IsNullOrWhiteSpace(value) ||
                options.Any(option => string.Equals(option.Value, value, StringComparison.OrdinalIgnoreCase)))
            {
                return;
            }

            var label = value;
            const string prefix = "index:";
            if (value.StartsWith(prefix, StringComparison.OrdinalIgnoreCase) &&
                int.TryParse(value.Substring(prefix.Length), NumberStyles.Integer, CultureInfo.InvariantCulture, out var index))
            {
                label = F("LOCPlayniteBootOptionMonitorUnavailable", index + 1);
            }

            options.Add(new LocalizedOption(value, label));
        }

        private List<LocalizedOption> BuildMonitorOptions(bool streaming)
        {
            var options = new List<LocalizedOption>();
            if (streaming)
            {
                options.Add(new LocalizedOption("clientResolution", L("LOCPlayniteBootOptionMonitorClientResolution")));
                options.Add(new LocalizedOption("inherit", L("LOCPlayniteBootOptionMonitorUseGeneral")));
            }

            if (!streaming)
            {
                options.Add(new LocalizedOption("playnite", L("LOCPlayniteBootOptionMonitorFollowPlaynite")));
            }

            options.Add(new LocalizedOption("auto", L("LOCPlayniteBootOptionMonitorAutomatic")));
            options.Add(new LocalizedOption("primary", L("LOCPlayniteBootOptionMonitorPrimary")));

            try
            {
                var screens = Forms.Screen.AllScreens;
                for (var index = 0; index < screens.Length; index++)
                {
                    var screen = screens[index];
                    var label = F(
                        "LOCPlayniteBootOptionMonitorIndexed",
                        index + 1,
                        screen.DeviceName,
                        screen.Bounds.Width,
                        screen.Bounds.Height);
                    options.Add(new LocalizedOption("index:" + index, label));
                }
            }
            catch
            {
                options.Add(new LocalizedOption("index:0", F("LOCPlayniteBootOptionMonitorSimple", 1)));
                options.Add(new LocalizedOption("index:1", F("LOCPlayniteBootOptionMonitorSimple", 2)));
            }

            return options;
        }

        private void BrowseVideo()
        {
            var initialDirectory = string.Empty;
            try
            {
                initialDirectory = Path.GetDirectoryName(GetConfiguredVideoPath());
            }
            catch
            {
                initialDirectory = string.Empty;
            }

            var filter = L("LOCPlayniteBootVideoFileFilter");
            var selected = string.IsNullOrWhiteSpace(initialDirectory)
                ? plugin.PlayniteApi.Dialogs.SelectFile(filter)
                : plugin.PlayniteApi.Dialogs.SelectFile(filter, initialDirectory);

            if (!string.IsNullOrWhiteSpace(selected))
            {
                Settings.VideoPath = Path.GetFullPath(selected);
                RefreshVideoLibrary(false);
            }
        }

        private void RestoreDefaultVideo()
        {
            Settings.VideoPath = plugin.Paths.DefaultVideoPath;
            RefreshVideoLibrary(false);
            RuntimeStatus = L("LOCPlayniteBootStatusDefaultVideoSelected");
        }

        private void OpenVideoFolder()
        {
            Directory.CreateDirectory(plugin.Paths.MediaDirectory);
            ShellService.OpenFolder(plugin.Paths.MediaDirectory);
        }

        private void RefreshVideoLibrary(bool updateStatus)
        {
            var selectedPath = GetConfiguredVideoPath();
            IReadOnlyList<string> libraryPaths;
            Exception refreshError = null;

            try
            {
                libraryPaths = videoLibrary.GetLibraryVideos();
            }
            catch (Exception exception)
            {
                libraryPaths = Array.Empty<string>();
                refreshError = exception;
            }

            var options = new List<VideoOption>();
            AddVideoOption(
                options,
                plugin.Paths.DefaultVideoPath,
                F("LOCPlayniteBootVideoDefaultLabel", SafeFileName(plugin.Paths.DefaultVideoPath)));

            foreach (var path in libraryPaths)
            {
                if (PathsEqual(path, plugin.Paths.DefaultVideoPath))
                {
                    continue;
                }

                AddVideoOption(options, path, SafeFileName(path));
            }

            if (!options.Any(option => PathsEqual(option.Path, selectedPath)))
            {
                var fileName = SafeFileName(selectedPath);
                var label = File.Exists(selectedPath)
                    ? F("LOCPlayniteBootVideoExternalLabel", fileName)
                    : F("LOCPlayniteBootVideoMissingLabel", fileName);
                AddVideoOption(options, selectedPath, label);
            }

            VideoOptions.Clear();
            foreach (var option in options)
            {
                VideoOptions.Add(option);
            }

            OnPropertyChanged(nameof(SelectedVideoPath));
            OnPropertyChanged(nameof(SelectedVideoPathDisplay));

            if (!updateStatus)
            {
                return;
            }

            RuntimeStatus = refreshError == null
                ? F("LOCPlayniteBootStatusVideoLibraryRefreshed", libraryPaths.Count)
                : F("LOCPlayniteBootStatusVideoLibraryRefreshFailed", refreshError.Message);
        }

        private static void AddVideoOption(List<VideoOption> options, string path, string label)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                return;
            }

            string normalizedPath;
            try
            {
                normalizedPath = Path.GetFullPath(path);
            }
            catch
            {
                normalizedPath = path;
            }

            if (options.Any(option => PathsEqual(option.Path, normalizedPath)))
            {
                return;
            }

            options.Add(new VideoOption(normalizedPath, label, normalizedPath));
        }

        private static string SafeFileName(string path)
        {
            try
            {
                var fileName = Path.GetFileName(path);
                return string.IsNullOrWhiteSpace(fileName) ? path : fileName;
            }
            catch
            {
                return path ?? string.Empty;
            }
        }

        private string GetConfiguredVideoPath()
        {
            try
            {
                return string.IsNullOrWhiteSpace(Settings?.VideoPath)
                    ? Path.GetFullPath(plugin.Paths.DefaultVideoPath)
                    : Path.GetFullPath(Settings.VideoPath);
            }
            catch
            {
                return Settings?.VideoPath ?? plugin.Paths.DefaultVideoPath;
            }
        }

        private static bool PathsEqual(string first, string second)
        {
            if (string.IsNullOrWhiteSpace(first) || string.IsNullOrWhiteSpace(second))
            {
                return false;
            }

            try
            {
                return string.Equals(
                    Path.GetFullPath(first),
                    Path.GetFullPath(second),
                    StringComparison.OrdinalIgnoreCase);
            }
            catch
            {
                return string.Equals(first, second, StringComparison.OrdinalIgnoreCase);
            }
        }

        private static bool IsManualMonitorSelection(string value)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                return false;
            }

            return !string.Equals(value, "playnite", StringComparison.OrdinalIgnoreCase) &&
                !string.Equals(value, "followPlaynite", StringComparison.OrdinalIgnoreCase) &&
                !string.Equals(value, "clientResolution", StringComparison.OrdinalIgnoreCase) &&
                !string.Equals(value, "client", StringComparison.OrdinalIgnoreCase) &&
                !string.Equals(value, "inherit", StringComparison.OrdinalIgnoreCase);
        }

        private void ResetSettings()
        {
            var result = plugin.PlayniteApi.Dialogs.ShowMessage(
                L("LOCPlayniteBootConfirmResetSettings"),
                PlayniteBootPlugin.ProductName,
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);
            if (result != MessageBoxResult.Yes)
            {
                return;
            }

            var defaults = PlayniteBootSettingsData.CreateDefault();
            defaults.VideoPath = plugin.Paths.DefaultVideoPath;
            Settings = defaults;
            RuntimeStatus = L("LOCPlayniteBootStatusDefaultsRestored");
        }

        private void InstallRuntime()
        {
            var result = plugin.PrepareRuntime(Settings, true);
            RuntimeStatus = F("LOCPlayniteBootStatusRuntimeInstalled", result.Version, result.CopiedFiles);
            plugin.PlayniteApi.Dialogs.ShowMessage(RuntimeStatus, PlayniteBootPlugin.ProductName);
        }

        private void CreateShortcut(ShortcutLocation location)
        {
            var validationErrors = new List<string>();
            ValidateShortcutName(validationErrors, Settings.ShortcutName);
            if (validationErrors.Count > 0)
            {
                throw new InvalidOperationException(validationErrors[0]);
            }

            plugin.CreateShortcut(Settings, location);
            var locationLabel = location == ShortcutLocation.Desktop
                ? L("LOCPlayniteBootLocationDesktop")
                : L("LOCPlayniteBootLocationStartMenu");
            var message = F("LOCPlayniteBootStatusShortcutCreated", Settings.ShortcutName, locationLabel);
            plugin.PlayniteApi.Dialogs.ShowMessage(message, PlayniteBootPlugin.ProductName);
            RuntimeStatus = message;
        }

        private void RemoveShortcut(ShortcutLocation location)
        {
            var locationLabel = location == ShortcutLocation.Desktop
                ? L("LOCPlayniteBootLocationDesktop")
                : L("LOCPlayniteBootLocationStartMenu");
            var result = plugin.PlayniteApi.Dialogs.ShowMessage(
                F("LOCPlayniteBootConfirmRemoveShortcut", locationLabel),
                PlayniteBootPlugin.ProductName,
                MessageBoxButton.YesNo,
                MessageBoxImage.Question);
            if (result != MessageBoxResult.Yes)
            {
                return;
            }

            var removed = plugin.RemoveShortcut(Settings, location);
            var message = removed
                ? F("LOCPlayniteBootStatusShortcutRemoved", locationLabel)
                : F("LOCPlayniteBootStatusShortcutNotFound", locationLabel);
            plugin.PlayniteApi.Dialogs.ShowMessage(message, PlayniteBootPlugin.ProductName);
            RuntimeStatus = message;
        }

        private void CopyDiagnostics()
        {
            try
            {
                var diagnostics = BuildDiagnostics();
                Clipboard.SetText(diagnostics);
                RuntimeStatus = L("LOCPlayniteBootStatusDiagnosticsCopied");
            }
            catch (Exception exception)
            {
                plugin.PlayniteApi.Dialogs.ShowErrorMessage(exception.Message, PlayniteBootPlugin.ProductName);
            }
        }

        private string BuildDiagnostics()
        {
            var extensionVersion = Assembly.GetExecutingAssembly().GetName().Version;
            var runtimeVersion = ReadRuntimeVersion();
            var videoExists = false;
            try
            {
                var path = string.IsNullOrWhiteSpace(Settings.VideoPath)
                    ? plugin.Paths.DefaultVideoPath
                    : Path.GetFullPath(Settings.VideoPath);
                videoExists = File.Exists(path) ||
                    (string.Equals(path, plugin.Paths.DefaultVideoPath, StringComparison.OrdinalIgnoreCase) &&
                     File.Exists(plugin.Paths.DefaultTemplateVideoPath));
            }
            catch
            {
                videoExists = false;
            }

            var b = new StringBuilder();
            b.AppendLine("Playnite Boot Screen diagnostics");
            b.AppendLine("Extension: " + (extensionVersion == null ? "unknown" : extensionVersion.ToString(3)));
            b.AppendLine("Runtime: " + runtimeVersion);
            b.AppendLine("Playnite: " + plugin.PlayniteApi.ApplicationInfo.ApplicationVersion);
            b.AppendLine("Language: " + plugin.PlayniteApi.ApplicationSettings.Language);
            b.AppendLine("Config version: " + RuntimeConfigWriter.CurrentConfigVersion);
            b.AppendLine("Mode: " + (Settings.WaitForVideoEnd ? "waitForVideoEnd" : "readyAndMinimumDuration"));
            b.AppendLine("Streaming preload: " + (Settings.Streaming != null && Settings.Streaming.Enabled ? "enabled" : "disabled"));
            b.AppendLine("Runtime installed: " + YesNo(File.Exists(plugin.Paths.ScriptPath) && File.Exists(plugin.Paths.ConfigPath)));
            b.AppendLine("Video exists: " + YesNo(videoExists));
            b.AppendLine("Desktop shortcut: " + YesNo(plugin.ShortcutExists(Settings, ShortcutLocation.Desktop)));
            b.AppendLine("Start menu shortcut: " + YesNo(plugin.ShortcutExists(Settings, ShortcutLocation.StartMenu)));
            return b.ToString().TrimEnd();
        }

        private void CopyToClipboard(string text)
        {
            try
            {
                Clipboard.SetText(text ?? string.Empty);
                RuntimeStatus = L("LOCPlayniteBootStatusCommandCopied");
            }
            catch (Exception exception)
            {
                plugin.PlayniteApi.Dialogs.ShowErrorMessage(exception.Message, PlayniteBootPlugin.ProductName);
            }
        }

        private void ExecuteAction(Action action)
        {
            try
            {
                action();
                RefreshRuntimeStatus(false);
            }
            catch (Exception exception)
            {
                plugin.PlayniteApi.Dialogs.ShowErrorMessage(exception.Message, PlayniteBootPlugin.ProductName);
            }
        }

        private void RefreshRuntimeStatus(bool overwriteActionStatus = true)
        {
            if (!overwriteActionStatus && !string.IsNullOrWhiteSpace(RuntimeStatus))
            {
                return;
            }

            if (File.Exists(plugin.Paths.ScriptPath) && File.Exists(plugin.Paths.ConfigPath))
            {
                RuntimeStatus = F("LOCPlayniteBootStatusRuntimeReady", ReadRuntimeVersion());
            }
            else if (Directory.Exists(plugin.Paths.RuntimeDirectory))
            {
                RuntimeStatus = L("LOCPlayniteBootStatusRuntimePartial");
            }
            else
            {
                RuntimeStatus = L("LOCPlayniteBootStatusRuntimeMissing");
            }
        }

        private string ReadRuntimeVersion()
        {
            try
            {
                var versionPath = Path.Combine(plugin.Paths.RuntimeDirectory, "VERSION.txt");
                return File.Exists(versionPath) ? File.ReadAllText(versionPath).Trim() : "not installed";
            }
            catch
            {
                return "unknown";
            }
        }

        private static void ValidateShortcutName(List<string> errors, string name)
        {
            var trimmed = (name ?? string.Empty).Trim();
            if (string.IsNullOrWhiteSpace(trimmed))
            {
                errors.Add(L("LOCPlayniteBootValidationShortcutEmpty"));
                return;
            }

            if (trimmed.Length > 120)
            {
                errors.Add(L("LOCPlayniteBootValidationShortcutLength"));
            }

            if (trimmed.IndexOfAny(Path.GetInvalidFileNameChars()) >= 0 ||
                trimmed.EndsWith(".", StringComparison.Ordinal) ||
                trimmed.EndsWith(" ", StringComparison.Ordinal))
            {
                errors.Add(L("LOCPlayniteBootValidationShortcutCharacters"));
            }

            var baseName = trimmed.Split('.')[0].ToUpperInvariant();
            var reserved = new[] { "CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9" };
            if (reserved.Contains(baseName))
            {
                errors.Add(L("LOCPlayniteBootValidationShortcutReserved"));
            }
        }

        private static void ValidatePositive(List<string> errors, int value, string label)
        {
            if (value <= 0)
            {
                errors.Add(F("LOCPlayniteBootValidationPositive", label));
            }
        }

        private static void ValidateNonNegative(List<string> errors, int value, string label)
        {
            if (value < 0)
            {
                errors.Add(F("LOCPlayniteBootValidationNonNegative", label));
            }
        }

        private static void ValidateMinimum(List<string> errors, int value, int minimum, string label)
        {
            if (value < minimum)
            {
                errors.Add(F("LOCPlayniteBootValidationMinimum", label, minimum));
            }
        }

        private static string L(string key)
        {
            return key.GetLocalized();
        }

        private static string F(string key, params object[] values)
        {
            return string.Format(CultureInfo.CurrentCulture, L(key), values);
        }

        private static string YesNo(bool value)
        {
            return value ? "yes" : "no";
        }
    }
}
