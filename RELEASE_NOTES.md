# Playnite Boot Screen 0.6.2

This maintenance release hardens streaming foreground handling for the rare case where Playnite Fullscreen replaces its initially launched process during startup.

Highlights:
- Detached/Continue delegates foreground permission to the preload Host before exiting;
- the Host keeps tracking Playnite if the initially launched PID is replaced during startup;
- the final Playnite window receives foreground handoff attempts immediately before and after the boot-overlay fade;
- explicit Alt+Tab/yield behavior is preserved, so the launcher does not reclaim focus after the user intentionally switches away;
- existing Prep and Detached command strings remain unchanged;
- runtime updated to 1.0.6.

Existing shortcuts, custom media, settings, and streaming configuration remain compatible.
