# Playnite add-on database submission

These files are templates for the official Playnite add-on database.

Before submitting:

1. publish the GitHub release and confirm the `.pext` URL in `installer.yaml`;
2. confirm the raw URLs use the final repository owner and default branch;
3. verify with Playnite Toolbox:

```powershell
Toolbox.exe verify installer .\distribution\installer.yaml
Toolbox.exe verify addon .\distribution\addon.yaml
```

Submit `addon.yaml` to the `addons/generic` directory of `JosefNemec/PlayniteAddonDatabase` through a pull request.
