param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$manifest = Get-Content -LiteralPath (Join-Path $root 'PlayniteBoot\extension.yaml') -Raw
$assemblyInfo = Get-Content -LiteralPath (Join-Path $root 'PlayniteBoot\Properties\AssemblyInfo.cs') -Raw
$installer = Get-Content -LiteralPath (Join-Path $root 'distribution\installer.yaml') -Raw

$escapedVersion = [regex]::Escape($Version)
$checks = @(
    @{ Name = 'extension manifest'; Pass = $manifest -match (("(?m)^Version:\s*{0}\s*$") -f $escapedVersion) },
    @{ Name = 'assembly version'; Pass = $assemblyInfo -match (('AssemblyVersion\("{0}\.0"\)') -f $escapedVersion) },
    @{ Name = 'assembly file version'; Pass = $assemblyInfo -match (('AssemblyFileVersion\("{0}\.0"\)') -f $escapedVersion) },
    @{ Name = 'installer manifest'; Pass = $installer -match (("(?m)^\s*- Version:\s*{0}\s*$") -f $escapedVersion) },
    @{ Name = 'package URL'; Pass = $installer -match (('/v{0}/Playnite-Boot-Screen-v{0}\.pext') -f $escapedVersion) }
)

$failed = @($checks | Where-Object { -not $_.Pass })
foreach ($check in $checks) {
    Write-Host ("{0}: {1}" -f $check.Name, $(if ($check.Pass) { 'OK' } else { 'FAILED' }))
}

if ($failed.Count -gt 0) {
    throw 'Release metadata is inconsistent.'
}

Write-Host "Release metadata is consistent for version $Version."
