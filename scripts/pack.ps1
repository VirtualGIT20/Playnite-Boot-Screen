param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',
    [string]$Destination = (Join-Path (Split-Path -Parent $PSScriptRoot) 'dist'),
    [string]$ToolboxPath
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'build.ps1') -Configuration $Configuration

if (-not $ToolboxPath) {
    $candidates = @(
        (Join-Path $env:LOCALAPPDATA 'Playnite\Toolbox.exe'),
        (Join-Path $env:ProgramFiles 'Playnite\Toolbox.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'Playnite\Toolbox.exe')
    )
    $ToolboxPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

if (-not $ToolboxPath -or -not (Test-Path -LiteralPath $ToolboxPath -PathType Leaf)) {
    throw 'Toolbox.exe was not found. Install Playnite or pass -ToolboxPath explicitly.'
}

$manifestPath = Join-Path $root 'PlayniteBoot\extension.yaml'
$versionLine = Select-String -LiteralPath $manifestPath -Pattern '^Version:\s*(.+)$' | Select-Object -First 1
if (-not $versionLine) {
    throw 'Could not read the extension version from extension.yaml.'
}
$version = $versionLine.Matches[0].Groups[1].Value.Trim()

$output = Join-Path $root "PlayniteBoot\bin\$Configuration"
New-Item -Path $Destination -ItemType Directory -Force | Out-Null
$before = @(Get-ChildItem -LiteralPath $Destination -Filter '*.pext' -File -ErrorAction SilentlyContinue | ForEach-Object FullName)

& $ToolboxPath pack $output $Destination
if ($LASTEXITCODE -ne 0) {
    throw "Packaging failed with exit code $LASTEXITCODE."
}

$package = Get-ChildItem -LiteralPath $Destination -Filter '*.pext' -File |
    Where-Object { $before -notcontains $_.FullName } |
    Sort-Object LastWriteTimeUtc -Descending |
    Select-Object -First 1
if (-not $package) {
    $package = Get-ChildItem -LiteralPath $Destination -Filter '*.pext' -File |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1
}
if (-not $package) {
    throw 'Toolbox completed but no .pext package was found.'
}

$targetPath = Join-Path $Destination "Playnite-Boot-Screen-v$version.pext"
if (-not [string]::Equals($package.FullName, $targetPath, [StringComparison]::OrdinalIgnoreCase)) {
    if (Test-Path -LiteralPath $targetPath) {
        Remove-Item -LiteralPath $targetPath -Force
    }
    Move-Item -LiteralPath $package.FullName -Destination $targetPath
}

$hash = Get-FileHash -LiteralPath $targetPath -Algorithm SHA256
$hashPath = $targetPath + '.sha256'
"$($hash.Hash.ToLowerInvariant())  $([IO.Path]::GetFileName($targetPath))" |
    Set-Content -LiteralPath $hashPath -Encoding ASCII

Write-Host "Package: $targetPath"
Write-Host "SHA-256: $hashPath"
