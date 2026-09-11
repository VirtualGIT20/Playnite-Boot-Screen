# Releasing

## 1. Update metadata

Update all version references:

- `PlayniteBoot/extension.yaml`
- `PlayniteBoot/Properties/AssemblyInfo.cs`
- `PlayniteBoot/RuntimeTemplate/VERSION.txt` when managed runtime files change (diagnostic metadata; managed files are synchronized by content)
- `CHANGELOG.md`
- `RELEASE_NOTES.md`
- `distribution/installer.yaml`

From the Visual Studio terminal, resolve and verify the manifest version:

```powershell
$manifest = Get-Content .\PlayniteBoot\extension.yaml -Raw
if ($manifest -notmatch '(?m)^Version:\s*(\d+\.\d+\.\d+)\s*$') {
    throw 'Invalid extension version.'
}
$version = $Matches[1]
.\scripts\verify-release.ps1 -Version $version
```

## 2. Build and package locally

```powershell
.\scripts\pack.ps1 -Configuration Release
```

Playnite's Toolbox must be used for `.pext` packaging because it prepares the plugin package from the built extension directory.

## 3. Push the release branch

Commit the release changes, push the branch, open a pull request, and wait for CI to complete successfully. Merge the pull request into `main` only after the release checklist is complete.

## 4. Create the tag

From an updated and clean `main` branch:

```powershell
$manifest = Get-Content .\PlayniteBoot\extension.yaml -Raw
$null = $manifest -match '(?m)^Version:\s*(\d+\.\d+\.\d+)\s*$'
$version = $Matches[1]
git tag -a "v$version" -m "Playnite Boot Screen $version"
git push origin "v$version"
```

The release workflow builds the plugin, installs Playnite on the Windows runner, packages with Toolbox, generates a SHA-256 file, and creates the GitHub release.

## 5. Publish through the Playnite add-on database

After the release asset URL is live:

1. verify `distribution/installer.yaml` and `distribution/addon.yaml`;
2. confirm the new package entry in `distribution/installer.yaml` points to the live `.pext` asset;
3. for an add-on that is already published, no new database pull request is required: the existing store entry follows `InstallerManifestUrl` to this repository and Playnite can discover the new compatible package;
4. open a pull request against `JosefNemec/PlayniteAddonDatabase` only for the initial publication or when the central add-on metadata / `InstallerManifestUrl` must change.
