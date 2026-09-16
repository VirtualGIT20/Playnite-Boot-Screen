$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

function Get-RelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $rootPath = [IO.Path]::GetFullPath($root)
    $rootPath = $rootPath.TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)) + [IO.Path]::DirectorySeparatorChar
    return [IO.Path]::GetFullPath($Path).Substring($rootPath.Length)
}

Write-Host 'Checking PowerShell syntax...'
$parseFailures = New-Object System.Collections.Generic.List[string]
$scriptFiles = Get-ChildItem -LiteralPath $root -Filter '*.ps1' -File -Recurse |
    Where-Object { $_.FullName -notmatch '[\\/](\.git|\.vs|bin|obj|packages|dist|artifacts)[\\/]' }

foreach ($scriptFile in $scriptFiles) {
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $scriptFile.FullName,
        [ref]$tokens,
        [ref]$errors) | Out-Null

    foreach ($parseError in @($errors)) {
        $parseFailures.Add((
            '{0}:{1}:{2}: {3}' -f
            (Get-RelativePath -Path $scriptFile.FullName),
            $parseError.Extent.StartLineNumber,
            $parseError.Extent.StartColumnNumber,
            $parseError.Message))
    }
}

if ($parseFailures.Count -gt 0) {
    throw "PowerShell syntax errors were found:`n$($parseFailures -join "`n")"
}

Write-Host 'Checking localization keys...'
function Get-LocalizationKeys {
    param([Parameter(Mandatory = $true)][string]$Path)

    $content = Get-Content -LiteralPath $Path -Raw -Encoding UTF8
    $keys = @([regex]::Matches($content, 'x:Key="([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    $duplicates = @($keys | Group-Object | Where-Object Count -gt 1 | ForEach-Object Name)
    if ($duplicates.Count -gt 0) {
        throw "Duplicate localization keys in $(Get-RelativePath -Path $Path): $($duplicates -join ', ')"
    }

    return $keys | Sort-Object -Unique
}

$englishPath = Join-Path $root 'PlayniteBoot\Localization\en_US.xaml'
$italianPath = Join-Path $root 'PlayniteBoot\Localization\it_IT.xaml'
$englishKeys = @(Get-LocalizationKeys -Path $englishPath)
$italianKeys = @(Get-LocalizationKeys -Path $italianPath)
$keyDifferences = @(Compare-Object -ReferenceObject $englishKeys -DifferenceObject $italianKeys)
if ($keyDifferences.Count -gt 0) {
    throw "English and Italian localization keys differ:`n$($keyDifferences | Out-String)"
}

Write-Host 'Checking setup-first shortcut integration...'
$settingsDataPath = Join-Path $root 'PlayniteBoot\Models\PlayniteBootSettingsData.cs'
$settingsModelPath = Join-Path $root 'PlayniteBoot\PlayniteBootSettings.cs'
$shortcutServicePath = Join-Path $root 'PlayniteBoot\Services\ShortcutService.cs'
$shortcutInstallerPath = Join-Path $root 'PlayniteBoot\RuntimeTemplate\Install-Shortcut.ps1'
$shortcutIconPath = Join-Path $root 'PlayniteBoot\RuntimeTemplate\PlayniteBoot.ico'
$settingsViewPath = Join-Path $root 'PlayniteBoot\PlayniteBootSettingsView.xaml'
foreach ($requiredPath in @($settingsDataPath, $settingsModelPath, $shortcutServicePath, $shortcutInstallerPath, $shortcutIconPath, $settingsViewPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required setup/shortcut file not found: $requiredPath"
    }
}
$settingsDataSource = Get-Content -LiteralPath $settingsDataPath -Raw -Encoding UTF8
$settingsModelSource = Get-Content -LiteralPath $settingsModelPath -Raw -Encoding UTF8
$shortcutServiceSource = Get-Content -LiteralPath $shortcutServicePath -Raw -Encoding UTF8
$shortcutInstallerSource = Get-Content -LiteralPath $shortcutInstallerPath -Raw -Encoding UTF8
$settingsViewSource = Get-Content -LiteralPath $settingsViewPath -Raw -Encoding UTF8
$shortcutChecks = @(
    @{ Name = 'setup-first tab'; Pass = $settingsViewSource -match 'LOCPlayniteBootTabSetup' },
    @{ Name = 'shortcut icon modes'; Pass = $settingsDataSource -match 'ShortcutIconModes' -and $settingsDataSource -match 'CurrentSettingsVersion = 6' },
    @{ Name = 'custom ICO picker'; Pass = $settingsModelSource -match 'BrowseShortcutIconCommand' -and $settingsModelSource -match 'ShortcutIconsDirectory' -and $settingsModelSource -match 'SHA256.Create' },
    @{ Name = 'explicit shortcut icon handoff'; Pass = $shortcutServiceSource -match 'PLAYNITEBOOT_SHORTCUT_ICON_B64' -and $shortcutInstallerSource -match 'PLAYNITEBOOT_SHORTCUT_ICON_B64' },
    @{ Name = 'bundled PBS shortcut icon'; Pass = (Get-Item -LiteralPath $shortcutIconPath).Length -gt 1024 }
)
$failedShortcutChecks = @($shortcutChecks | Where-Object { -not $_.Pass })
foreach ($check in $shortcutChecks) {
    Write-Host ("Setup/shortcut {0}: {1}" -f $check.Name, $(if ($check.Pass) { 'OK' } else { 'FAILED' }))
}
if ($failedShortcutChecks.Count -gt 0) {
    throw 'Setup-first shortcut integration is incomplete.'
}
Write-Host 'Setup-first shortcut integration: OK'

Write-Host 'Checking runtime and media files...'
$runtimeVersionPath = Join-Path $root 'PlayniteBoot\RuntimeTemplate\VERSION.txt'
$runtimeVersion = (Get-Content -LiteralPath $runtimeVersionPath -Raw).Trim()
if ($runtimeVersion -notmatch '^\d+\.\d+\.\d+$') {
    throw "Invalid runtime version: $runtimeVersion"
}

$runtimeScriptPath = Join-Path $root 'PlayniteBoot\RuntimeTemplate\PlayniteBoot.ps1'
$runtimeScript = Get-Content -LiteralPath $runtimeScriptPath -Raw -Encoding UTF8
$runtimeBehaviorChecks = @(
    @{ Name = 'explicit Alt+Tab hook'; Pass = $runtimeScript -match 'WmPlayniteBootAltTab' },
    @{ Name = 'streaming cancellation guard'; Pass = $runtimeScript -match 'streaming-cancelled\.flag' },
    @{ Name = 'Playnite Fullscreen cancellation'; Pass = $runtimeScript -match '\$stopPlayniteFullscreen' },
    @{ Name = 'foreground polling removed'; Pass = $runtimeScript -notmatch '\$yieldForegroundIfNeeded' },
    @{ Name = 'Playnite monitor following'; Pass = $runtimeScript -match 'fullscreenConfig\.json' },
    @{ Name = 'monitor fallback'; Pass = $runtimeScript -match 'MonitorFallback' },
    @{ Name = 'cross-monitor readiness'; Pass = $runtimeScript -match 'largest intersection area|bestIntersectionArea' },
    @{ Name = 'PID top-level window readiness fallback'; Pass = $runtimeScript -match 'GetTopLevelWindowsForProcess' -and $runtimeScript -match 'GetWindowThreadProcessId' -and $runtimeScript -match 'Preserve the 0\.8\.0 behavior whenever MainWindowHandle' -and $runtimeScript -match '\$windowReadiness\.WindowHandle' },
    @{ Name = 'Switch topology-aware readiness'; Pass = $runtimeScript -match 'Get-ScreenTopologySignature' -and $runtimeScript -match 'Display topology changed during Switch readiness' -and $runtimeScript -match '\$readinessScreens' },
    @{ Name = 'MediaFailed black-surface fallback'; Pass = $runtimeScript -match 'The failed video surface was hidden' -and $runtimeScript -match '\$media\.Visibility = \[System\.Windows\.Visibility\]::Hidden' -and $runtimeScript -match '-not \$state\.VideoFailed' }
)

$failedRuntimeBehaviorChecks = @($runtimeBehaviorChecks | Where-Object { -not $_.Pass })
foreach ($check in $runtimeBehaviorChecks) {
    Write-Host ("Runtime {0}: {1}" -f $check.Name, $(if ($check.Pass) { 'OK' } else { 'FAILED' }))
}

if ($failedRuntimeBehaviorChecks.Count -gt 0) {
    throw 'Required runtime behavior is missing from the runtime script.'
}

Write-Host 'Checking Desktop-to-Fullscreen integration...'
$switchBootstrapPath = Join-Path $root 'PlayniteBoot\RuntimeTemplate\SwitchBootstrap.ps1'
$switchServicePath = Join-Path $root 'PlayniteBoot\Services\DesktopFullscreenSwitchService.cs'
$runtimeInstallerPath = Join-Path $root 'PlayniteBoot\Services\RuntimeInstaller.cs'
foreach ($requiredPath in @($switchBootstrapPath, $switchServicePath, $runtimeInstallerPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required Desktop-to-Fullscreen integration file not found: $requiredPath"
    }
}
$switchBootstrapSource = Get-Content -LiteralPath $switchBootstrapPath -Raw -Encoding UTF8
$switchServiceSource = Get-Content -LiteralPath $switchServicePath -Raw -Encoding UTF8
$runtimeInstallerSource = Get-Content -LiteralPath $runtimeInstallerPath -Raw -Encoding UTF8
if ($runtimeScript -notmatch "ValidateSet\('Standalone', 'Preload', 'Continue', 'Host', 'Switch'\)" -or
    $runtimeScript -notmatch 'SwitchBootstrapActive' -or
    $switchBootstrapSource -notmatch 'SwitchBootstrapActive' -or
    $switchServiceSource -notmatch 'SwitchToFullscreenMode' -or
    $runtimeInstallerSource -notmatch 'FilesHaveSameContent' -or
    $runtimeInstallerSource -notmatch 'SwitchBootstrap\.ps1') {
    throw 'Desktop-to-Fullscreen integration or content-aware runtime synchronization is incomplete.'
}
Write-Host 'Desktop-to-Fullscreen integration: OK'
Write-Host 'Checking managed video library integration...'
$videoLibraryPath = Join-Path $root 'PlayniteBoot\Services\VideoLibraryService.cs'
$videoCompatibilityPath = Join-Path $root 'PlayniteBoot\Services\VideoCompatibilityService.cs'
$configWriterPath = Join-Path $root 'PlayniteBoot\Services\RuntimeConfigWriter.cs'
foreach ($requiredPath in @($videoLibraryPath, $videoCompatibilityPath, $configWriterPath, $settingsViewPath)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required video library file not found: $requiredPath"
    }
}

$videoLibrarySource = Get-Content -LiteralPath $videoLibraryPath -Raw -Encoding UTF8
$videoCompatibilitySource = Get-Content -LiteralPath $videoCompatibilityPath -Raw -Encoding UTF8
$configWriterSource = Get-Content -LiteralPath $configWriterPath -Raw -Encoding UTF8
$settingsViewSource = Get-Content -LiteralPath $settingsViewPath -Raw -Encoding UTF8
$acceptedVideoExtensions = @('\.mp4', '\.mkv', '\.webm', '\.avi', '\.mov')
$missingVideoExtensions = @($acceptedVideoExtensions | Where-Object { $videoLibrarySource -notmatch $_ })
$managedVideoChecks = @(
    @{ Name = 'top-level managed media enumeration'; Pass = $videoLibrarySource -match 'SearchOption\.TopDirectoryOnly' },
    @{ Name = 'accepted playback formats'; Pass = $missingVideoExtensions.Count -eq 0 },
    @{ Name = 'WebM compatibility resolver'; Pass = $configWriterSource -match 'videoCompatibility\.Resolve' -and $videoCompatibilitySource -match '\.webm' },
    @{ Name = 'runtime-relative playback path'; Pass = $configWriterSource.Contains('return @".\" + relativePath;') },
    @{ Name = 'video library refresh command'; Pass = $settingsViewSource -match 'RefreshVideoLibraryCommand' },
    @{ Name = 'bundled media seeding'; Pass = $runtimeInstallerSource -match 'Directory\.EnumerateFiles\(templateMediaDirectory' -and $runtimeInstallerSource -match 'VideoLibraryService\.IsAcceptedVideo' }
)

$failedManagedVideoChecks = @($managedVideoChecks | Where-Object { -not $_.Pass })
foreach ($check in $managedVideoChecks) {
    Write-Host ("Managed video {0}: {1}" -f $check.Name, $(if ($check.Pass) { 'OK' } else { 'FAILED' }))
}

if ($failedManagedVideoChecks.Count -gt 0) {
    throw 'Managed video library integration is incomplete.'
}
Write-Host 'Managed video library integration: OK'

$videoPath = Join-Path $root 'PlayniteBoot\RuntimeTemplate\media\boot-4k60.mp4'
if (-not (Test-Path -LiteralPath $videoPath -PathType Leaf)) {
    throw "Default video not found: $videoPath"
}
if ((Get-Item -LiteralPath $videoPath).Length -lt 1MB) {
    throw 'The default video is unexpectedly small.'
}
$videoHash = (Get-FileHash -LiteralPath $videoPath -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "Default video SHA-256: $videoHash"

Write-Host 'Checking tracked repository files...'
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    $gitPath = $git.Source
    $trackedFiles = @(& $gitPath -C $root ls-files)
    if ($LASTEXITCODE -ne 0) {
        throw 'git ls-files failed.'
    }

    $forbiddenTrackedFiles = @(
        $trackedFiles | Where-Object {
            $_ -match '(^|/)(\.vs|bin|obj|packages|dist|artifacts)/' -or
            $_ -match '\.(pdb|pext|sha256|tmp|user|suo)$'
        }
    )

    if ($forbiddenTrackedFiles.Count -gt 0) {
        throw "Generated or local files are tracked by Git:`n$($forbiddenTrackedFiles -join "`n")"
    }
}

Write-Host "Source verification completed. Localization keys: $($englishKeys.Count). Runtime version: $runtimeVersion."
