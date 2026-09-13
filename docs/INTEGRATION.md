# Theme and helper integration

Playnite Boot Screen exposes a small runtime contract for themes or helper plugins that would otherwise show their own startup intro.

## Startup intro marker

While Playnite Boot Screen is actively covering a Playnite startup, it publishes this named Windows manual-reset event:

```text
Local\PlayniteBootScreen.StartupIntroHandled.v1
```

The event is **signaled** while the boot overlay is active and is reset/disposed when Playnite Boot Screen releases the startup overlay. It is published for Standalone, Streaming Host, and Desktop-to-Fullscreen Switch flows.

The marker is intentionally independent from the selected video, video file name, theme, and video-end behavior. It only means:

> Playnite Boot Screen is handling the startup presentation for this launch.

A consumer such as a theme helper can check the marker immediately before starting its own intro. If the event exists and is signaled, the helper should skip its intro for that launch. If the event is missing or not signaled, the helper should keep its normal behavior.

## C# example

Open, check, and dispose the event for each decision. Do not cache the handle.

```csharp
using System;
using System.Threading;

private const string StartupIntroHandledEventName =
    @"Local\PlayniteBootScreen.StartupIntroHandled.v1";

private static bool IsStartupIntroHandledByPlayniteBootScreen()
{
    EventWaitHandle marker = null;

    try
    {
        marker = EventWaitHandle.OpenExisting(StartupIntroHandledEventName);
        return marker.WaitOne(0);
    }
    catch (WaitHandleCannotBeOpenedException)
    {
        return false;
    }
    catch (UnauthorizedAccessException)
    {
        return false;
    }
    finally
    {
        if (marker != null)
        {
            marker.Dispose();
        }
    }
}
```

Typical usage:

```csharp
if (startupIntroEnabled && !IsStartupIntroHandledByPlayniteBootScreen())
{
    PlayStartupIntro();
}
```

## Compatibility contract

The `.v1` suffix is part of the public contract. Compatible changes keep the same name and semantics. Any future breaking change will use a new marker version instead of silently changing `v1`.

The marker does not require another plugin to read Playnite Boot Screen's settings or runtime `config.json`, and Playnite Boot Screen does not need to know which theme/helper consumes it.
