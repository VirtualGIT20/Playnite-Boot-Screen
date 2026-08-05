# Releasing

## 1. Update metadata

Update all version references:

- `PlayniteBoot/extension.yaml`
- `PlayniteBoot/Properties/AssemblyInfo.cs`
- `PlayniteBoot/RuntimeTemplate/VERSION.txt` only when managed runtime files change
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

## 5. Submit to the Playnite add-on database

After the release asset URL is live:

1. verify `distribution/installer.yaml` and `distribution/addon.yaml`;
2. fork `JosefNemec/PlayniteAddonDatabase`;
3. add the add-on manifest under `addons/generic`;
4. open a pull request.
