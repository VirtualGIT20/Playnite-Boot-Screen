param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Debug',
    [string]$ExtensionsPath = (Join-Path $env:APPDATA 'Playnite\Extensions')
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
& (Join-Path $PSScriptRoot 'build.ps1') -Configuration $Configuration

$source = Join-Path $root "PlayniteBoot\bin\$Configuration"
$destination = Join-Path $ExtensionsPath 'PlayniteBoot_71b5c099-3c25-4fe7-b26f-1262c7f0e138'

if (Test-Path -LiteralPath $destination) {
    Remove-Item -LiteralPath $destination -Recurse -Force
}

New-Item -Path $destination -ItemType Directory -Force | Out-Null
Copy-Item -Path (Join-Path $source '*') -Destination $destination -Recurse -Force
Write-Host "Extension copied to: $destination"
Write-Host 'Restart Playnite to load the development build.'
