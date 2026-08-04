# Contributing

Contributions are welcome.

## Before opening an issue

- Use the latest release.
- Reproduce the issue with Playnite's default Desktop and Fullscreen themes when possible.
- Use **Copy diagnostic information** in the extension settings.
- For startup or streaming failures, attach the relevant tail of Playnite's `playnite.log`, `extensions.log`, and the runtime log. Remove personal paths when desired.

## Development

See `docs/DEVELOPMENT.md`. Keep the plugin ID unchanged and preserve backward compatibility for existing settings and runtime configuration.

## Pull requests

- Build the Release configuration without warnings.
- Keep user-facing strings in both `Localization/en_US.xaml` and `Localization/it_IT.xaml`.
- Do not add network telemetry or credentials handling.
- Document behavior changes in `CHANGELOG.md`.
