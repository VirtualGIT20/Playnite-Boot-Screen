# Playnite Boot Screen 0.8.1

Version 0.8.1 focuses on a clearer first-time setup and more reliable Desktop-to-Fullscreen startup on systems that change display topology while Playnite is opening.

## Highlights

- **Guided Quick Setup** — the main settings page now keeps the essential launch, video, and reveal controls together, with a compact Ready / Setup needed status in the header.
- **Shortcut icon choices** — PBS-managed Desktop and Start menu shortcuts can use the Playnite Boot Screen icon, the Playnite Fullscreen icon, or a custom `.ico` file copied into persistent extension data.
- **Topology-aware Desktop → Fullscreen readiness** — Switch mode refreshes the active Windows display layout while Playnite starts, so setups that move from Extended mode to a single TV/display no longer keep checking against a stale monitor snapshot.
- **Safer Fullscreen window detection** — PBS still prefers Playnite's `MainWindowHandle`, but can fall back to another visible top-level window owned by the exact Playnite Fullscreen PID when the main handle is temporarily pointing at a transient window.
- **Safer video failure fallback** — if Windows media playback fails during a display change, the failed video surface is hidden and PBS continues waiting for Playnite instead of leaving a frozen frame visible.

## Compatibility

Existing 0.8.0 settings are migrated automatically. Existing installations keep the historical Playnite Fullscreen shortcut icon choice, while fresh installations default to the Playnite Boot Screen icon. Custom media, shortcut state, and streaming configuration remain compatible.

The dynamic display-topology refresh is limited to Desktop-to-Fullscreen Switch readiness; it does not retarget or move the PBS overlay. Manual monitor selection remains available for explicit overlay placement.

Runtime updated to 1.0.13.
