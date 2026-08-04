# Release checklist — 0.4.0

## Code and behavior

- [ ] Release build completes with zero warnings and errors.
- [ ] Settings page opens in English and Italian.
- [ ] Settings save and cancel correctly.
- [ ] Direct cold launch succeeds.
- [ ] Launch while Playnite Desktop is already open switches to Fullscreen successfully.
- [ ] Wait-for-video-end mode succeeds.
- [ ] Streaming Preload and Continue succeed on the target virtual display.
- [ ] Desktop and Start shortcuts can be created, renamed, and removed.
- [ ] Runtime log rotates to `PlayniteBoot.log.1` after 2 MiB.

## Packaging

- [ ] `scripts/verify-release.ps1 -Version 0.4.0` succeeds.
- [ ] `scripts/pack.ps1 -Configuration Release` creates the expected `.pext`.
- [ ] SHA-256 file matches the package.
- [ ] The `.pext` installs on a clean Playnite profile.
- [ ] Upgrade from extension 0.3.1 preserves settings and custom media.

## GitHub

- [ ] Repository description, topics, and license are set.
- [ ] CI workflow succeeds.
- [ ] Tag `v0.4.0` creates a release with `.pext` and checksum.
- [ ] Release notes mention the theme-related black-screen diagnostic.

## Playnite add-on database

- [ ] GitHub release asset URL is live.
- [ ] `distribution/installer.yaml` verifies with Toolbox.
- [ ] `distribution/addon.yaml` verifies with Toolbox.
- [ ] Add-on database pull request is opened under `addons/generic`.
