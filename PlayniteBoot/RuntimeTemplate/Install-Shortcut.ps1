[CmdletBinding()]
param(
    [string]$ShortcutName = 'Playnite Fullscreen',
    [string]$ShortcutDescription = 'Launch Playnite Fullscreen with a custom boot video and no console window.',
    [switch]$Desktop,
    [switch]$StartMenu
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-Utf8Base64EnvironmentValue {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [string]$Fallback
    )

    $encoded = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($encoded)) {
        return $Fallback
    }

    try {
        return [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
    }
    catch {
        throw "Invalid Base64 value in environment variable $Name."
    }
}

$ShortcutName = Get-Utf8Base64EnvironmentValue -Name 'PLAYNITEBOOT_SHORTCUT_NAME_B64' -Fallback $ShortcutName
$ShortcutDescription = Get-Utf8Base64EnvironmentValue -Name 'PLAYNITEBOOT_SHORTCUT_DESCRIPTION_B64' -Fallback $ShortcutDescription

if ([string]::IsNullOrWhiteSpace($ShortcutName)) {
    throw 'ShortcutName cannot be empty.'
}
if ($ShortcutName.IndexOfAny([IO.Path]::GetInvalidFileNameChars()) -ge 0 -or
    $ShortcutName.EndsWith('.') -or
    $ShortcutName.EndsWith(' ')) {
    throw 'ShortcutName contains invalid filename characters or ends with a dot or space.'
}

$scriptDirectory = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDirectory)) {
    $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$launcherPath = Join-Path $scriptDirectory 'PlayniteBoot.ps1'
$wrapperPath = Join-Path $scriptDirectory 'Launch-PlayniteBoot.vbs'
$configPath = Join-Path $scriptDirectory 'config.json'
$wscriptPath = Join-Path $env:SystemRoot 'System32\wscript.exe'

foreach ($requiredPath in @($launcherPath, $wrapperPath, $wscriptPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required file not found: $requiredPath"
    }
}

# WScript does not create a console window. //B suppresses Windows Script Host error dialogs.
$arguments = '//B //Nologo "{0}"' -f $wrapperPath

# Backward compatibility: without a switch, create the Desktop shortcut.
if (-not $Desktop -and -not $StartMenu) {
    $Desktop = $true
}

$shortcutPaths = New-Object System.Collections.Generic.List[string]

if ($Desktop) {
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $shortcutPaths.Add((Join-Path $desktopPath ($ShortcutName + '.lnk')))
}

if ($StartMenu) {
    $startMenuPath = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
    if (-not (Test-Path -LiteralPath $startMenuPath -PathType Container)) {
        New-Item -ItemType Directory -Path $startMenuPath -Force | Out-Null
    }
    $shortcutPaths.Add((Join-Path $startMenuPath ($ShortcutName + '.lnk')))
}

function Resolve-ConfiguredPath([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }

    $expanded = [Environment]::ExpandEnvironmentVariables($Value)
    if ([IO.Path]::IsPathRooted($expanded)) {
        return [IO.Path]::GetFullPath($expanded)
    }

    return [IO.Path]::GetFullPath((Join-Path $scriptDirectory $expanded))
}

$iconCandidates = New-Object System.Collections.Generic.List[string]

# First choice: an explicit Playnite path configured in config.json.
if (Test-Path -LiteralPath $configPath -PathType Leaf) {
    try {
        $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($config.playniteExecutable -and [string]$config.playniteExecutable -ne 'auto') {
            $configuredPlaynite = Resolve-ConfiguredPath ([string]$config.playniteExecutable)
            if ($configuredPlaynite) { $iconCandidates.Add($configuredPlaynite) }
        }
    }
    catch {
        Write-Warning "Could not read config.json to determine the icon: $($_.Exception.Message)"
    }
}

if ($env:LOCALAPPDATA) { $iconCandidates.Add((Join-Path $env:LOCALAPPDATA 'Playnite\Playnite.FullscreenApp.exe')) }
if ($env:ProgramFiles) { $iconCandidates.Add((Join-Path $env:ProgramFiles 'Playnite\Playnite.FullscreenApp.exe')) }
if (${env:ProgramFiles(x86)}) { $iconCandidates.Add((Join-Path ${env:ProgramFiles(x86)} 'Playnite\Playnite.FullscreenApp.exe')) }

$iconPath = $iconCandidates |
    Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) } |
    Select-Object -First 1

$shell = New-Object -ComObject WScript.Shell
foreach ($shortcutPath in $shortcutPaths) {
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $wscriptPath
    $shortcut.Arguments = $arguments
    $shortcut.WorkingDirectory = $scriptDirectory
    $shortcut.Description = $ShortcutDescription
    if ($iconPath) {
        $shortcut.IconLocation = "$iconPath,0"
    }
    $shortcut.Save()
    Write-Host "Created: $shortcutPath" -ForegroundColor Green
}

Write-Host "No-console wrapper: $wrapperPath"
Write-Host 'Existing shortcuts created with older versions may need to be recreated.' -ForegroundColor Yellow
