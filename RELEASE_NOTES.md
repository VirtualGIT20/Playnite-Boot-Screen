# Playnite Boot Screen 0.6.1

This maintenance release fixes foreground handling when Playnite Fullscreen is launched through streaming Prep/Detached commands.

Highlights:
- Detached/Continue now launches Playnite Fullscreen directly, preserving the normal Windows foreground launch context;
- the preload Host adopts the launched Playnite PID and keeps the boot overlay visible until Playnite is ready;
- fixes Playnite Fullscreen sometimes remaining behind a terminal or other foreground application after the overlay closes;
- existing Prep and Detached command strings remain unchanged;
- runtime updated to 1.0.5.

Existing shortcuts, custom media, settings, and streaming configuration remain compatible.
