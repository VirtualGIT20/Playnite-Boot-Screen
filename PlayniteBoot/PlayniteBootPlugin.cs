using Playnite.SDK;
using Playnite.SDK.Data;
using Playnite.SDK.Events;
using Playnite.SDK.Plugins;
using PlayniteBoot.Models;
using PlayniteBoot.Services;
using System;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Controls;

namespace PlayniteBoot
{
    public class PlayniteBootPlugin : GenericPlugin
    {
        public const string ProductName = "Playnite Boot Screen";
        private static readonly ILogger logger = LogManager.GetLogger();
        private readonly RuntimeInstaller runtimeInstaller;
        private readonly RuntimeConfigWriter configWriter;
        private readonly ShortcutService shortcutService;
        private readonly DesktopFullscreenSwitchService desktopFullscreenSwitchService;
        private readonly object runtimeOperationLock = new object();

        public override Guid Id { get; } = Guid.Parse("71b5c099-3c25-4fe7-b26f-1262c7f0e138");
        public RuntimePaths Paths { get; }
        public CommandGenerator Commands { get; }
        public PlayniteBootSettingsViewModel SettingsViewModel { get; }

        public PlayniteBootPlugin(IPlayniteAPI api) : base(api)
        {
            var installPath = Path.GetDirectoryName(typeof(PlayniteBootPlugin).Assembly.Location);
            Paths = new RuntimePaths(GetPluginUserDataPath(), installPath);
            Commands = new CommandGenerator(Paths);
            runtimeInstaller = new RuntimeInstaller(Paths);
            configWriter = new RuntimeConfigWriter(Paths, PlayniteApi.Paths.ConfigurationPath);
            shortcutService = new ShortcutService(Paths);
            SettingsViewModel = new PlayniteBootSettingsViewModel(this);
            desktopFullscreenSwitchService = new DesktopFullscreenSwitchService(
                Paths,
                () => SettingsViewModel.Settings.EnableDesktopFullscreenSwitch);

            Properties = new GenericPluginProperties
            {
                HasSettings = true
            };
        }

        public override ISettings GetSettings(bool firstRunSettings)
        {
            return SettingsViewModel;
        }

        public override UserControl GetSettingsView(bool firstRunSettings)
        {
            return new PlayniteBootSettingsView();
        }

        public override void OnApplicationStarted(OnApplicationStartedEventArgs args)
        {
            if (PlayniteApi.ApplicationInfo.Mode == ApplicationMode.Desktop)
            {
                try
                {
                    var appWindow = PlayniteApi.Dialogs.GetCurrentAppWindow();
                    if (!desktopFullscreenSwitchService.Attach(appWindow))
                    {
                        logger.Warn(ProductName + " could not attach Desktop-to-Fullscreen switch handling to the Playnite window.");
                    }
                }
                catch (Exception exception)
                {
                    logger.Error(exception, ProductName + " failed to attach Desktop-to-Fullscreen switch handling.");
                }
            }

            // Take a snapshot on Playnite's UI thread, then perform disk work in
            // the background. All runtime mutations are serialized by the lock.
            var settingsSnapshot = Serialization.GetClone(SettingsViewModel.Settings);
            Task.Run(() =>
            {
                try
                {
                    PrepareRuntime(settingsSnapshot, false);
                }
                catch (Exception exception)
                {
                    logger.Error(exception, ProductName + " runtime initialization failed.");
                }
            });
        }

        public override void OnApplicationStopped(OnApplicationStoppedEventArgs args)
        {
            desktopFullscreenSwitchService.Detach();
        }

        public RuntimeInstallResult PrepareRuntime(PlayniteBootSettingsData settings, bool forceUpdate)
        {
            lock (runtimeOperationLock)
            {
                var result = runtimeInstaller.EnsureInstalled(forceUpdate);
                configWriter.Write(settings);
                logger.Info($"{ProductName} runtime ready at {Paths.RuntimeDirectory}. Version {result.Version}.");
                return result;
            }
        }

        public void WriteRuntimeConfig(PlayniteBootSettingsData settings)
        {
            lock (runtimeOperationLock)
            {
                configWriter.Write(settings);
            }
        }

        public string CreateShortcut(PlayniteBootSettingsData settings, ShortcutLocation location)
        {
            lock (runtimeOperationLock)
            {
                var result = runtimeInstaller.EnsureInstalled(false);
                configWriter.Write(settings);
                logger.Info($"{ProductName} runtime ready at {Paths.RuntimeDirectory}. Version {result.Version}.");
                return shortcutService.Create(
                    location,
                    settings.ShortcutName,
                    "LOCPlayniteBootShortcutDescription".GetLocalized());
            }
        }

        public bool RemoveShortcut(PlayniteBootSettingsData settings, ShortcutLocation location)
        {
            lock (runtimeOperationLock)
            {
                return shortcutService.Remove(location, settings.ShortcutName);
            }
        }

        public bool ShortcutExists(PlayniteBootSettingsData settings, ShortcutLocation location)
        {
            lock (runtimeOperationLock)
            {
                return shortcutService.Exists(location, settings.ShortcutName);
            }
        }
    }
}
