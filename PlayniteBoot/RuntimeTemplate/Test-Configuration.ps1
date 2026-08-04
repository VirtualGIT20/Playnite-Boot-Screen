[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$scriptDirectory = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDirectory)) {
    $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$configPath = Join-Path $scriptDirectory 'config.json'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Configuration file not found: $configPath"
}

$config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

function Resolve-LocalPath([string]$Value) {
    $expanded = [Environment]::ExpandEnvironmentVariables($Value)
    if ([IO.Path]::IsPathRooted($expanded)) {
        return [IO.Path]::GetFullPath($expanded)
    }
    return [IO.Path]::GetFullPath((Join-Path $scriptDirectory $expanded))
}

function Get-PropertyValue($Object, [string]$Name, $DefaultValue) {
    if ($null -eq $Object) { return $DefaultValue }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) { return $DefaultValue }
    return $property.Value
}

$configVersion = [int](Get-PropertyValue $config 'configVersion' 0)
$streaming = Get-PropertyValue $config 'streaming' $null
$legacyStreaming = $false
if ($null -eq $streaming) {
    $streaming = Get-PropertyValue $config 'vibepollo' $null
    $legacyStreaming = $null -ne $streaming
}

$powerShellPath = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
$launcherPath = Join-Path $scriptDirectory 'PlayniteBoot.ps1'
$wrapperPath = Join-Path $scriptDirectory 'Launch-PlayniteBoot.vbs'
$shortcutInstallerPath = Join-Path $scriptDirectory 'Install-Shortcut.ps1'
$wscriptPath = Join-Path $env:SystemRoot 'System32\wscript.exe'

Write-Host 'PlayniteBoot - configuration check' -ForegroundColor Cyan
Write-Host "Config version: $configVersion"
if ($legacyStreaming) {
    Write-Warning 'Legacy vibepollo section detected. Save settings in the extension to migrate to streaming.'
}
if ($configVersion -gt 1) {
    Write-Warning "Config version $configVersion is newer than the supported version 1."
}

Write-Host ''
Write-Host 'GENERAL SETTINGS' -ForegroundColor Cyan
Write-Host "Folder:         $scriptDirectory"
Write-Host "Video:          $(Resolve-LocalPath ([string]$config.videoPath))"
Write-Host "Monitor:        $($config.monitor)"
Write-Host "Arguments:      $($config.launchArguments)"
$loopVideo = [bool](Get-PropertyValue $config 'loopVideo' $false)
$waitForVideoEnd = [bool](Get-PropertyValue $config 'waitForVideoEnd' $false)
Write-Host "Loop video:     $loopVideo"
Write-Host "Wait for end:   $waitForVideoEnd"
Write-Host "Ready position: $($config.videoReadyPositionMilliseconds) ms"
Write-Host "Ready samples:  $($config.videoReadyAdvanceSamples)"
Write-Host "Ready timeout:  $($config.videoReadyTimeoutMilliseconds) ms"
Write-Host "Fade-in:        $($config.fadeInMilliseconds) ms"
Write-Host "Fade-out:       $($config.fadeOutMilliseconds) ms"
Write-Host "Stability:      $($config.readyStabilityMilliseconds) ms"
Write-Host 'Coverage:       at least 85% of the selected monitor (internal threshold)'

if ($loopVideo -and $waitForVideoEnd) {
    Write-Warning 'Invalid configuration: loopVideo and waitForVideoEnd cannot both be enabled.'
}
elseif ($waitForVideoEnd) {
    Write-Host 'OK: fade-out requires both Playnite readiness and the natural end of the video.' -ForegroundColor Green
    Write-Host 'Note: minimumVideoMilliseconds is ignored while the video remains playable.'
}

$video = Resolve-LocalPath ([string]$config.videoPath)
if (Test-Path -LiteralPath $video -PathType Leaf) {
    $item = Get-Item -LiteralPath $video
    Write-Host ("OK: video found ({0:N1} MB)." -f ($item.Length / 1MB)) -ForegroundColor Green
}
else {
    Write-Warning "Video not found: $video"
}

$playniteCandidates = @()
if ([string]$config.playniteExecutable -and [string]$config.playniteExecutable -ne 'auto') {
    $playniteCandidates += Resolve-LocalPath ([string]$config.playniteExecutable)
}
else {
    if ($env:LOCALAPPDATA) { $playniteCandidates += Join-Path $env:LOCALAPPDATA 'Playnite\Playnite.FullscreenApp.exe' }
    if ($env:ProgramFiles) { $playniteCandidates += Join-Path $env:ProgramFiles 'Playnite\Playnite.FullscreenApp.exe' }
    if (${env:ProgramFiles(x86)}) { $playniteCandidates += Join-Path ${env:ProgramFiles(x86)} 'Playnite\Playnite.FullscreenApp.exe' }
}

$playnite = $playniteCandidates | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } | Select-Object -First 1
if ($playnite) {
    Write-Host "OK: Playnite found: $playnite" -ForegroundColor Green
}
else {
    Write-Warning 'Playnite was not found in common locations. Configure playniteExecutable.'
}

Write-Host ''
Write-Host 'STREAMING INTEGRATION' -ForegroundColor Cyan
if ($null -eq $streaming) {
    Write-Warning 'The streaming section is missing.'
}
else {
    $enabled = [bool](Get-PropertyValue $streaming 'enabled' $true)
    $monitor = [string](Get-PropertyValue $streaming 'monitor' 'clientResolution')
    $preloadTimeout = [int](Get-PropertyValue $streaming 'preloadReadyTimeoutMilliseconds' 6000)
    $continueTimeout = [int](Get-PropertyValue $streaming 'continueWaitTimeoutMilliseconds' 10000)
    $abandonTimeout = [int](Get-PropertyValue $streaming 'preloadAbandonTimeoutMilliseconds' 30000)
    $fallbackMode = [string](Get-PropertyValue $streaming 'fallbackMode' 'standalone')

    Write-Host "Enabled:         $enabled"
    Write-Host "Preload monitor: $monitor"
    Write-Host "Preload timeout: $preloadTimeout ms"
    Write-Host "Continue timeout:$continueTimeout ms"
    Write-Host "Abandon timeout: $abandonTimeout ms"
    Write-Host "Fallback:        $fallbackMode"

    if ($fallbackMode.ToLowerInvariant() -ne 'standalone') {
        Write-Warning "Unsupported fallbackMode: $fallbackMode. Use 'standalone'."
    }

    $validMonitor = $monitor -match '^(?i:inherit|auto|cursor|primary|client|clientResolution|index:\d+)$'
    if (-not $validMonitor) {
        Write-Warning "Unrecognized streaming.monitor value: $monitor"
    }
}

Write-Host ''
Write-Host 'NO-CONSOLE SHORTCUT' -ForegroundColor Cyan
foreach ($item in @(
    @{ Name = 'VBS wrapper'; Path = $wrapperPath },
    @{ Name = 'Shortcut installer'; Path = $shortcutInstallerPath },
    @{ Name = 'Windows Script Host'; Path = $wscriptPath }
)) {
    if (Test-Path -LiteralPath $item.Path -PathType Leaf) {
        Write-Host "OK: $($item.Name): $($item.Path)" -ForegroundColor Green
    }
    else {
        Write-Warning "$($item.Name) not found: $($item.Path)"
    }
}
Write-Host ('Create or update a shortcut: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "{0}" -StartMenu' -f $shortcutInstallerPath)

Write-Host ''
Write-Host 'DIRECT LAUNCH' -ForegroundColor Cyan
Write-Host ('"{0}" -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "{1}"' -f $powerShellPath, $launcherPath)

Write-Host ''
Write-Host 'STREAMING - PREP COMMAND' -ForegroundColor Cyan
Write-Host ('"{0}" -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "{1}" -Mode Preload' -f $powerShellPath, $launcherPath)

Write-Host ''
Write-Host 'STREAMING - DETACHED COMMAND' -ForegroundColor Cyan
Write-Host ('"{0}" -NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "{1}" -Mode Continue' -f $powerShellPath, $launcherPath)

Write-Host ''
Write-Host 'No Undo command is required for PlayniteBoot.' -ForegroundColor Green
