# Playnite Boot Screen 0.7.0

This feature release extends Playnite Boot Screen to Playnite's native Desktop-to-Fullscreen transition and hardens runtime updates.

Highlights:
- the configured boot video can cover Playnite's built-in Desktop-to-Fullscreen switch;
- the new switch integration is enabled by default and can be disabled from the extension settings;
- a lightweight on-demand black bootstrap cover bridges the Desktop closing phase to the existing WPF boot overlay, with no resident helper process;
- Playnite still owns and performs its native Desktop-to-Fullscreen transition; if the cover cannot be armed, the integration fails open and Playnite continues normally;
- the existing monitor selection, video playback, readiness detection, fade, cancellation, and foreground handling are reused for the switch path;
- managed runtime files are synchronized by content on Playnite startup, so an outdated or modified managed file is repaired even if the runtime version marker was not changed;
- runtime updated to 1.0.7.

Existing shortcuts, custom media, settings, and Sunshine/Apollo streaming configuration remain compatible.
