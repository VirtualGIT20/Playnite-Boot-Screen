using Playnite.SDK;
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Windows;

namespace PlayniteBoot.Services
{
    /// <summary>
    /// Covers Playnite's built-in Desktop -> Fullscreen transition with the
    /// external boot runtime. The integration is best-effort and always fails
    /// open so Playnite can continue switching even if the cover cannot arm.
    /// </summary>
    internal sealed class DesktopFullscreenSwitchService
    {
        private const int ArmWaitMilliseconds = 2500;
        private const string SwitchMethodName = "SwitchToFullscreenMode";
        private const string SwitchTypeName = "Playnite.DesktopApp.ViewModels.DesktopAppViewModel";

        private static readonly ILogger logger = LogManager.GetLogger();
        private readonly RuntimePaths paths;
        private readonly Func<bool> isEnabled;
        private Window attachedWindow;
        private bool switchHandled;

        public DesktopFullscreenSwitchService(RuntimePaths paths, Func<bool> isEnabled)
        {
            this.paths = paths ?? throw new ArgumentNullException(nameof(paths));
            this.isEnabled = isEnabled ?? throw new ArgumentNullException(nameof(isEnabled));
        }

        public bool Attach(Window window)
        {
            if (window == null)
            {
                return false;
            }

            if (ReferenceEquals(attachedWindow, window))
            {
                return true;
            }

            Detach();
            attachedWindow = window;
            switchHandled = false;
            attachedWindow.Closing += Window_Closing;
            return true;
        }

        public void Detach()
        {
            if (attachedWindow != null)
            {
                attachedWindow.Closing -= Window_Closing;
                attachedWindow = null;
            }
        }

        private void Window_Closing(object sender, CancelEventArgs eventArgs)
        {
            if (eventArgs.Cancel || switchHandled || !IsEnabled())
            {
                return;
            }

            if (!IsDesktopToFullscreenSwitch(new StackTrace(false)))
            {
                return;
            }

            // Playnite calls Window.Close synchronously from SwitchToFullscreenMode.
            // Hold that Closing callback only until a black external cover is
            // rendered; once armed, Playnite is free to close Desktop and launch
            // Fullscreen behind the cover.
            switchHandled = true;

            // A streaming preload host already owns the target display with its
            // own boot overlay. Starting SwitchBootstrap as well would briefly
            // place a second black TopMost window above the running video before
            // the Switch runtime notices the launcher mutex and exits. Skip the
            // redundant cover and let the active streaming Host track Fullscreen.
            if (IsStreamingHostActive())
            {
                logger.Info(PlayniteBootPlugin.ProductName + " skipped the Desktop-to-Fullscreen switch cover because a streaming preload host is already active.");
                return;
            }

            TryArmSwitchCover(Process.GetCurrentProcess().Id, DateTime.UtcNow);
        }

        private bool IsStreamingHostActive()
        {
            Mutex existingMutex = null;
            try
            {
                existingMutex = Mutex.OpenExisting(GetStreamingHostMutexName(paths.ConfigPath));
                return true;
            }
            catch (WaitHandleCannotBeOpenedException)
            {
                return false;
            }
            catch (UnauthorizedAccessException)
            {
                // The named object exists even if this process cannot open it.
                // Treat that as an active Host so the switch integration fails
                // open instead of flashing a redundant black cover.
                return true;
            }
            catch (Exception exception)
            {
                logger.Warn(PlayniteBootPlugin.ProductName + " could not check the streaming preload host state: " + exception.Message);
                return false;
            }
            finally
            {
                if (existingMutex != null)
                {
                    existingMutex.Dispose();
                }
            }
        }

        private static string GetStreamingHostMutexName(string configPath)
        {
            using (var sha = SHA256.Create())
            {
                var identityBytes = Encoding.UTF8.GetBytes((configPath ?? string.Empty).ToLowerInvariant());
                var hashBytes = sha.ComputeHash(identityBytes);
                var hash = BitConverter.ToString(hashBytes).Replace("-", string.Empty).Substring(0, 16);
                return "Local\\PlayniteBoot_" + hash + "_Host";
            }
        }

        private bool IsEnabled()
        {
            try
            {
                return isEnabled();
            }
            catch (Exception exception)
            {
                logger.Warn(PlayniteBootPlugin.ProductName + " could not read the Desktop-to-Fullscreen switch setting: " + exception.Message);
                return false;
            }
        }

        private bool TryArmSwitchCover(int desktopProcessId, DateTime callbackUtc)
        {
            var bootstrapPath = Path.Combine(paths.RuntimeTemplateDirectory, "SwitchBootstrap.ps1");
            var runtimeScriptPath = Path.Combine(paths.RuntimeTemplateDirectory, "PlayniteBoot.ps1");

            if (!File.Exists(bootstrapPath) || !File.Exists(runtimeScriptPath) || !File.Exists(paths.ConfigPath))
            {
                logger.Warn(PlayniteBootPlugin.ProductName + " could not cover the Desktop-to-Fullscreen switch because the runtime is not ready.");
                return false;
            }

            var eventName = "Local\\PlayniteBootSwitchOverlay_" + desktopProcessId + "_" + Guid.NewGuid().ToString("N");
            using (var readyEvent = new EventWaitHandle(false, EventResetMode.ManualReset, eventName))
            {
                var startInfo = new ProcessStartInfo
                {
                    FileName = WindowsPowerShell.ExecutablePath,
                    Arguments = BuildArguments(
                        bootstrapPath,
                        runtimeScriptPath,
                        paths.ConfigPath,
                        callbackUtc.Ticks,
                        eventName),
                    UseShellExecute = false,
                    CreateNoWindow = true,
                    WindowStyle = ProcessWindowStyle.Hidden,
                    WorkingDirectory = paths.RuntimeTemplateDirectory
                };

                Process helper = null;
                try
                {
                    helper = Process.Start(startInfo);
                    if (helper == null)
                    {
                        logger.Warn(PlayniteBootPlugin.ProductName + " could not start the Desktop-to-Fullscreen switch cover.");
                        return false;
                    }

                    if (readyEvent.WaitOne(ArmWaitMilliseconds))
                    {
                        return true;
                    }

                    // A late cover is worse than no cover: it could appear after
                    // Desktop has already closed. Abort the helper and let Playnite
                    // continue its native switch normally.
                    TryTerminate(helper);
                    logger.Warn(PlayniteBootPlugin.ProductName + " switch cover did not become ready in time; continuing without it.");
                    return false;
                }
                catch (Exception exception)
                {
                    TryTerminate(helper);
                    logger.Error(exception, PlayniteBootPlugin.ProductName + " failed to start the Desktop-to-Fullscreen switch cover.");
                    return false;
                }
                finally
                {
                    if (helper != null)
                    {
                        helper.Dispose();
                    }
                }
            }
        }

        private static void TryTerminate(Process process)
        {
            if (process == null)
            {
                return;
            }

            try
            {
                if (!process.HasExited)
                {
                    process.Kill();
                }
            }
            catch
            {
            }
        }

        private static string BuildArguments(
            string bootstrapPath,
            string runtimeScriptPath,
            string configPath,
            long callbackUtcTicks,
            string eventName)
        {
            return string.Join(" ", new[]
            {
                "-NoLogo",
                "-NoProfile",
                "-NonInteractive",
                "-ExecutionPolicy Bypass",
                "-STA",
                "-WindowStyle Hidden",
                "-File " + Quote(bootstrapPath),
                "-ConfigPath " + Quote(configPath),
                "-RuntimeScriptPath " + Quote(runtimeScriptPath),
                "-SwitchReadyEventName " + Quote(eventName),
                "-SwitchStartUtcTicks " + callbackUtcTicks
            });
        }

        private static string Quote(string value)
        {
            return "\"" + (value ?? string.Empty).Replace("\"", "\\\"") + "\"";
        }

        private static bool IsDesktopToFullscreenSwitch(StackTrace stack)
        {
            var frames = stack.GetFrames();
            if (frames == null)
            {
                return false;
            }

            foreach (var frame in frames)
            {
                var method = frame.GetMethod();
                var declaringType = method != null ? method.DeclaringType : null;
                if (declaringType != null &&
                    string.Equals(declaringType.FullName, SwitchTypeName, StringComparison.Ordinal) &&
                    string.Equals(method.Name, SwitchMethodName, StringComparison.Ordinal))
                {
                    return true;
                }
            }

            return false;
        }
    }
}
