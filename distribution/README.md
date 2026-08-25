# Playnite add-on database distribution

The official Playnite add-on database stores the add-on manifest, whose `InstallerManifestUrl` points to the raw `distribution/installer.yaml` on this repository's default branch.

For a normal update of an already published add-on:

1. publish the GitHub release and confirm the `.pext` URL used by the new package entry in `installer.yaml`;
2. keep previous package entries in `installer.yaml` and add the new version at the top;
3. verify both manifests with Playnite Toolbox:

```powershell
Toolbox.exe verify installer .\distribution\installer.yaml
Toolbox.exe verify addon .\distribution\addon.yaml
```

No new pull request to `JosefNemec/PlayniteAddonDatabase` is required for each version because the existing store entry reads the external installer manifest. Submit a database pull request only for initial publication or when the central add-on metadata / `InstallerManifestUrl` changes.
