# Releasing

## 1. Update metadata

Update all version references:

- `PlayniteBoot/extension.yaml`
- `PlayniteBoot/Properties/AssemblyInfo.cs`
- `PlayniteBoot/RuntimeTemplate/VERSION.txt` when the runtime changes
- `CHANGELOG.md`
- `RELEASE_NOTES.md`
- `distribution/installer.yaml`

Run:

```powershell
.\scripts\verify-release.ps1 -Version 0.4.0
```

## 2. Build and package locally

```powershell
.\scripts\pack.ps1 -Configuration Release
```

Playnite's Toolbox must be used for `.pext` packaging because it prepares the plugin package from the built extension directory.

## 3. Push the repository

For a new repository:

```powershell
.\scripts\publish-github.ps1
```

The script uses the current Git identity and GitHub CLI authentication.

## 4. Create the tag

```powershell
git tag -a v0.4.0 -m "Playnite Boot Screen 0.4.0"
git push origin v0.4.0
```

The release workflow builds the plugin, installs Playnite on the Windows runner, packages with Toolbox, generates a SHA-256 file, and creates the GitHub release.

## 5. Submit to the Playnite add-on database

After the release asset URL is live:

1. verify `distribution/installer.yaml` and `distribution/addon.yaml`;
2. fork `JosefNemec/PlayniteAddonDatabase`;
3. add the add-on manifest under `addons/generic`;
4. open a pull request.
