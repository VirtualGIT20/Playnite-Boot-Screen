# Playnite Boot Screen 0.7.1

This maintenance hotfix corrects the Desktop-to-Fullscreen bootstrap cover on high-DPI and virtual displays.
Highlights:
- the temporary black handoff cover now resolves the selected monitor's physical position and resolution instead of treating DPI-virtualized WinForms bounds as physical pixels;
- the bootstrap cover is created under a temporary per-monitor DPI context, which is restored before the existing WPF boot overlay continues;
- this prevents the cover from appearing as a smaller black rectangle in the top-left corner before the video on high-scaling displays, including 4K virtual displays;
- the normal WPF overlay, video playback, Standalone flow, Sunshine/Apollo streaming flow, monitor selection, foreground handling, and log rotation are unchanged;
- no additional per-switch logging is introduced by this hotfix;
- runtime updated to 1.0.8.
Existing shortcuts, custom media, settings, and streaming configuration remain compatible.
