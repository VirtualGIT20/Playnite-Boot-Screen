<#
.SYNOPSIS
    Mostra un video di avvio e avvia Playnite in modalita Fullscreen.

.DESCRIPTION
    Lo script supporta due flussi, entrambi basati sullo stesso config.json:

    - Standalone: mostra il video, avvia Playnite e dissolve l'overlay quando
      la finestra Fullscreen e stabile.
    - Streaming: the Prep command uses Preload to prepare the video on the target
      display; the Detached command uses Continue to launch Playnite behind
      the same overlay.

    La modalita Host e interna: viene avviata automaticamente da Preload e non
    deve essere configurata manualmente.

.NOTES
    Compatibile con Windows PowerShell 5.1. Tutte le funzioni sono mantenute
    nello stesso file per semplificare installazione e aggiornamenti.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Standalone', 'Preload', 'Continue', 'Host')]
    [string]$Mode = 'Standalone'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# =============================================================================
# 1. Bootstrap e risoluzione dei percorsi
# =============================================================================

# In Windows PowerShell 5.1, $PSScriptRoot puo essere vuoto in alcuni
# contesti. Risolviamo i percorsi dopo il blocco param, mantenendo la sequenza
# di fallback gia collaudata nella baseline.
$scriptDirectory = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDirectory)) {
    $scriptFile = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($scriptFile)) {
        $scriptFile = $MyInvocation.MyCommand.Definition
    }

    if (-not [string]::IsNullOrWhiteSpace($scriptFile)) {
        $scriptDirectory = Split-Path -Parent $scriptFile
    }
}

if ([string]::IsNullOrWhiteSpace($scriptDirectory)) {
    $scriptDirectory = (Get-Location).ProviderPath
}

$scriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    $scriptPath = Join-Path -Path $scriptDirectory -ChildPath 'PlayniteBoot.ps1'
}
$scriptPath = [IO.Path]::GetFullPath($scriptPath)

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path -Path $scriptDirectory -ChildPath 'config.json'
}
elseif (-not [IO.Path]::IsPathRooted($ConfigPath)) {
    $ConfigPath = Join-Path -Path $scriptDirectory -ChildPath $ConfigPath
}

$ConfigPath = [IO.Path]::GetFullPath($ConfigPath)

# =============================================================================
# 2. Helper generali e configurazione
# =============================================================================

function Get-ConfigValue {
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        $Config,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        $DefaultValue
    )

    if ($null -eq $Config) {
        return $DefaultValue
    }

    $property = $Config.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $DefaultValue
    }

    return $property.Value
}

function Get-NestedConfigValue {
    param(
        [Parameter(Mandatory = $true)]
        $Config,

        [Parameter(Mandatory = $true)]
        [string]$Section,

        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        $DefaultValue
    )

    $sectionValue = Get-ConfigValue -Config $Config -Name $Section -DefaultValue $null
    return Get-ConfigValue -Config $sectionValue -Name $Name -DefaultValue $DefaultValue
}

function Resolve-ConfiguredPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$BaseDirectory
    )

    $expandedPath = [Environment]::ExpandEnvironmentVariables($Path)
    if ([IO.Path]::IsPathRooted($expandedPath)) {
        return [IO.Path]::GetFullPath($expandedPath)
    }

    return [IO.Path]::GetFullPath((Join-Path -Path $BaseDirectory -ChildPath $expandedPath))
}

function Get-MinimumInteger {
    param(
        [Parameter(Mandatory = $true)]
        [int]$Value,

        [Parameter(Mandatory = $true)]
        [int]$Minimum,

        [Parameter(Mandatory = $true)]
        [int]$Fallback
    )

    if ($Value -lt $Minimum) {
        return $Fallback
    }

    return $Value
}

function Get-ClampedDouble {
    param(
        [Parameter(Mandatory = $true)]
        [double]$Value,

        [Parameter(Mandatory = $true)]
        [double]$Minimum,

        [Parameter(Mandatory = $true)]
        [double]$Maximum
    )

    if ($Value -lt $Minimum) { return $Minimum }
    if ($Value -gt $Maximum) { return $Maximum }
    return $Value
}

function Find-PlayniteFullscreenExecutable {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfiguredPath,

        [Parameter(Mandatory = $true)]
        [string]$BaseDirectory
    )

    if (-not [string]::IsNullOrWhiteSpace($ConfiguredPath) -and $ConfiguredPath -ne 'auto') {
        $resolvedPath = Resolve-ConfiguredPath -Path $ConfiguredPath -BaseDirectory $BaseDirectory
        if (Test-Path -LiteralPath $resolvedPath -PathType Leaf) {
            return $resolvedPath
        }

        throw "Playnite was not found at the configured path: $resolvedPath"
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    if ($env:LOCALAPPDATA) {
        $candidates.Add((Join-Path $env:LOCALAPPDATA 'Playnite\Playnite.FullscreenApp.exe'))
    }
    if ($env:ProgramFiles) {
        $candidates.Add((Join-Path $env:ProgramFiles 'Playnite\Playnite.FullscreenApp.exe'))
    }
    if (${env:ProgramFiles(x86)}) {
        $candidates.Add((Join-Path ${env:ProgramFiles(x86)} 'Playnite\Playnite.FullscreenApp.exe'))
    }

    # La ricerca nel registro e solo un fallback: eventuali errori non devono
    # impedire l'avvio quando uno dei percorsi standard e valido.
    $registryRoots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
    )

    foreach ($registryRoot in $registryRoots) {
        try {
            $entries = Get-ItemProperty -Path $registryRoot -ErrorAction SilentlyContinue |
                Where-Object {
                    $displayName = $_.PSObject.Properties['DisplayName']
                    $installLocation = $_.PSObject.Properties['InstallLocation']
                    $null -ne $displayName -and
                        $null -ne $installLocation -and
                        [string]$displayName.Value -like 'Playnite*' -and
                        -not [string]::IsNullOrWhiteSpace([string]$installLocation.Value)
                }

            foreach ($entry in $entries) {
                $location = [string]$entry.PSObject.Properties['InstallLocation'].Value
                $candidates.Add((Join-Path $location 'Playnite.FullscreenApp.exe'))
            }
        }
        catch {
            # Rilevamento opzionale: i percorsi standard restano disponibili.
        }
    }

    foreach ($candidate in ($candidates | Select-Object -Unique)) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            return [IO.Path]::GetFullPath($candidate)
        }
    }

    throw 'Playnite.FullscreenApp.exe could not be found automatically. Set playniteExecutable in config.json.'
}

function Get-RunningFullscreenProcess {
    $processes = @(Get-Process -Name 'Playnite.FullscreenApp' -ErrorAction SilentlyContinue)
    if ($processes.Count -eq 0) {
        return $null
    }

    $processWithWindow = $processes |
        Where-Object {
            try {
                $_.Refresh()
                $_.MainWindowHandle -ne [IntPtr]::Zero
            }
            catch {
                $false
            }
        } |
        Select-Object -First 1

    if ($null -ne $processWithWindow) {
        return $processWithWindow
    }

    return $processes | Select-Object -First 1
}

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Configuration file not found: $ConfigPath"
}

$baseDirectory = Split-Path -Parent $ConfigPath
$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$streamingCancellationPath = Join-Path $baseDirectory 'streaming-cancelled.flag'
$script:continueWasCancelled = $false

$logEnabled = [bool](Get-ConfigValue -Config $config -Name 'logEnabled' -DefaultValue $true)
$logPathValue = [string](Get-ConfigValue -Config $config -Name 'logPath' -DefaultValue '.\logs\PlayniteBoot.log')
$logPath = Resolve-ConfiguredPath -Path $logPathValue -BaseDirectory $baseDirectory

# Keep one bounded backup so diagnostics cannot grow indefinitely. This is an
# internal safety policy rather than a user-facing tuning option.
$logMaximumBytes = 2MB
$logBackupPath = $logPath + '.1'

function Get-StableHash16 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Identity
    )

    $sha = [Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [Text.Encoding]::UTF8.GetBytes($Identity.ToLowerInvariant())
        $hashBytes = $sha.ComputeHash($bytes)
        return ([BitConverter]::ToString($hashBytes)).Replace('-', '').Substring(0, 16)
    }
    finally {
        $sha.Dispose()
    }
}

$logMutexName = 'Local\PlayniteBoot_Log_{0}' -f (Get-StableHash16 -Identity $logPath)
$logMutex = [System.Threading.Mutex]::new($false, $logMutexName)

function Rotate-LogIfNeeded {
    param(
        [Parameter(Mandatory = $true)]
        [int]$IncomingBytes
    )

    if (-not (Test-Path -LiteralPath $logPath -PathType Leaf)) {
        return
    }

    $currentLength = (Get-Item -LiteralPath $logPath).Length
    if (($currentLength + $IncomingBytes) -le $logMaximumBytes) {
        return
    }

    if (Test-Path -LiteralPath $logBackupPath -PathType Leaf) {
        Remove-Item -LiteralPath $logBackupPath -Force
    }

    Move-Item -LiteralPath $logPath -Destination $logBackupPath -Force
}

function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [ValidateSet('INFO', 'WARN', 'ERROR')]
        [string]$Level = 'INFO'
    )

    if (-not $logEnabled) {
        return
    }

    $logMutexAcquired = $false
    try {
        try {
            $logMutexAcquired = $logMutex.WaitOne(2000)
        }
        catch [System.Threading.AbandonedMutexException] {
            # The previous writer terminated while holding the mutex. Ownership
            # is transferred to this process, so logging can safely continue.
            $logMutexAcquired = $true
        }

        if (-not $logMutexAcquired) {
            return
        }

        $logDirectory = Split-Path -Parent $logPath
        if (-not (Test-Path -LiteralPath $logDirectory)) {
            New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
        }

        $line = '{0:yyyy-MM-dd HH:mm:ss.fff} [{1}] [{2}] {3}' -f (Get-Date), $Level, $Mode, $Message
        $lineBytes = [Text.Encoding]::UTF8.GetByteCount($line + [Environment]::NewLine)
        Rotate-LogIfNeeded -IncomingBytes $lineBytes
        Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    }
    catch {
        # Diagnostic logging must never block the launcher.
    }
    finally {
        if ($logMutexAcquired) {
            try { $logMutex.ReleaseMutex() } catch {}
        }
    }
}

$settings = $null

$configVersion = [int](Get-ConfigValue -Config $config -Name 'configVersion' -DefaultValue 0)
$streamingConfig = Get-ConfigValue -Config $config -Name 'streaming' -DefaultValue $null
$usingLegacyStreamingSection = $false
if ($null -eq $streamingConfig) {
    $streamingConfig = Get-ConfigValue -Config $config -Name 'vibepollo' -DefaultValue $null
    $usingLegacyStreamingSection = $null -ne $streamingConfig
}

# Streaming settings are isolated so Standalone behavior remains unchanged.
$streamingSettings = [PSCustomObject]@{
    Enabled = [bool](Get-ConfigValue -Config $streamingConfig -Name 'enabled' -DefaultValue $true)
    Monitor = [string](Get-ConfigValue -Config $streamingConfig -Name 'monitor' -DefaultValue 'clientResolution')
    PreloadReadyTimeoutMilliseconds = $(Get-MinimumInteger -Value ([int](Get-ConfigValue -Config $streamingConfig -Name 'preloadReadyTimeoutMilliseconds' -DefaultValue 6000)) -Minimum 1000 -Fallback 1000)
    ContinueWaitTimeoutMilliseconds = $(Get-MinimumInteger -Value ([int](Get-ConfigValue -Config $streamingConfig -Name 'continueWaitTimeoutMilliseconds' -DefaultValue 10000)) -Minimum 1000 -Fallback 1000)
    PreloadAbandonTimeoutMilliseconds = $(Get-MinimumInteger -Value ([int](Get-ConfigValue -Config $streamingConfig -Name 'preloadAbandonTimeoutMilliseconds' -DefaultValue 30000)) -Minimum 5000 -Fallback 5000)
    FallbackMode = [string](Get-ConfigValue -Config $streamingConfig -Name 'fallbackMode' -DefaultValue 'standalone')
}

if ($usingLegacyStreamingSection) {
    Write-Log 'Legacy config section vibepollo detected. It is supported for compatibility; save settings in the extension to migrate to streaming.' 'WARN'
}
if ($configVersion -gt 2) {
    Write-Log "Config version $configVersion is newer than the supported version 2. Unknown options will be ignored." 'WARN'
}

# =============================================================================
# 3. Prep / Detached streaming coordination
# =============================================================================

function Get-CoordinationNames {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Identity
    )

    $hash = Get-StableHash16 -Identity $Identity

    return [PSCustomObject]@{
        LauncherMutex = "Local\PlayniteBoot_${hash}_Launcher"
        HostMutex = "Local\PlayniteBoot_${hash}_Host"
        ReadyEvent = "Local\PlayniteBoot_${hash}_Ready"
        ContinueEvent = "Local\PlayniteBoot_${hash}_Continue"
        StopEvent = "Local\PlayniteBoot_${hash}_Stop"
    }
}

function New-CoordinationEvent {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $createdNew = $false
    return [System.Threading.EventWaitHandle]::new(
        $false,
        [System.Threading.EventResetMode]::ManualReset,
        $Name,
        [ref]$createdNew
    )
}

function Test-NamedMutexExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $existingMutex = $null
    try {
        $existingMutex = [System.Threading.Mutex]::OpenExisting($Name)
        return $true
    }
    catch [System.Threading.WaitHandleCannotBeOpenedException] {
        return $false
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $existingMutex) {
            $existingMutex.Dispose()
        }
    }
}

function Wait-NamedMutexToDisappear {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [int]$TimeoutMilliseconds
    )

    $watch = [Diagnostics.Stopwatch]::StartNew()
    while ($watch.ElapsedMilliseconds -lt $TimeoutMilliseconds) {
        if (-not (Test-NamedMutexExists -Name $Name)) {
            return $true
        }

        Start-Sleep -Milliseconds 50
    }

    return (-not (Test-NamedMutexExists -Name $Name))
}

function Close-CoordinationHandles {
    param(
        [Parameter(Mandatory = $false)]$ReadyEvent,
        [Parameter(Mandatory = $false)]$ContinueEvent,
        [Parameter(Mandatory = $false)]$StopEvent
    )

    if ($null -ne $ReadyEvent) { $ReadyEvent.Dispose() }
    if ($null -ne $ContinueEvent) { $ContinueEvent.Dispose() }
    if ($null -ne $StopEvent) { $StopEvent.Dispose() }
}

function Clear-StreamingCancellation {
    try {
        if (Test-Path -LiteralPath $streamingCancellationPath -PathType Leaf) {
            Remove-Item -LiteralPath $streamingCancellationPath -Force
        }
    }
    catch {
        Write-Log "Could not clear the previous streaming cancellation marker: $($_.Exception.Message)" 'WARN'
    }
}

function Set-StreamingCancellation {
    try {
        [IO.File]::WriteAllText(
            $streamingCancellationPath,
            [DateTime]::UtcNow.ToString('O'),
            [Text.Encoding]::UTF8
        )
    }
    catch {
        Write-Log "Could not persist the streaming cancellation marker: $($_.Exception.Message)" 'WARN'
    }
}

function Test-StreamingCancellation {
    try {
        if (-not (Test-Path -LiteralPath $streamingCancellationPath -PathType Leaf)) {
            return $false
        }

        return $true
    }
    catch {
        Write-Log "Could not read the streaming cancellation marker: $($_.Exception.Message)" 'WARN'
        return $false
    }
}

function Start-PreloadHostProcess {
    $powerShellPath = Join-Path $PSHOME 'powershell.exe'
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $powerShellPath
    $processInfo.Arguments = '-NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "{0}" -ConfigPath "{1}" -Mode Host' -f $scriptPath, $ConfigPath
    $processInfo.WorkingDirectory = $scriptDirectory
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    $processInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden

    Write-Log 'Starting the video preload host process.'
    $hostProcess = [System.Diagnostics.Process]::Start($processInfo)
    if ($null -eq $hostProcess) {
        throw 'Could not start the preload host process.'
    }
}

function Invoke-PreloadCommand {
    # Ogni Prep apre una nuova sessione. Un eventuale marker rimasto da una
    # cancellazione precedente non deve influenzare il nuovo avvio. Non lo
    # rimuoviamo se un host e ancora attivo, per non perdere una cancellazione
    # appena richiesta durante una chiamata Prep duplicata.
    if (-not (Test-NamedMutexExists -Name $coordinationNames.HostMutex)) {
        Clear-StreamingCancellation
    }

    if (-not $streamingSettings.Enabled) {
        Write-Log 'Streaming integration is disabled. The Prep command will exit without starting preload.' 'WARN'
        return 0
    }

    $readyEvent = $null
    $continueEvent = $null
    $stopEvent = $null

    try {
        $readyEvent = New-CoordinationEvent -Name $coordinationNames.ReadyEvent
        $continueEvent = New-CoordinationEvent -Name $coordinationNames.ContinueEvent
        $stopEvent = New-CoordinationEvent -Name $coordinationNames.StopEvent

        if (-not (Test-NamedMutexExists -Name $coordinationNames.HostMutex)) {
            # Gli eventi sono ManualReset: vanno azzerati prima di una nuova
            # sessione per non riutilizzare segnali lasciati da un host precedente.
            [void]$readyEvent.Reset()
            [void]$continueEvent.Reset()
            [void]$stopEvent.Reset()
            Start-PreloadHostProcess
        }
        else {
            Write-Log 'A preload host is already active. Waiting for its ready signal.'
        }

        if ($readyEvent.WaitOne($streamingSettings.PreloadReadyTimeoutMilliseconds)) {
            Write-Log 'Preload is ready: the video is visible and advancing. The Prep command can exit.'
            return 0
        }

        Write-Log "Preload was not ready within $($streamingSettings.PreloadReadyTimeoutMilliseconds) ms. Stopping the host; Continue will use the standalone fallback." 'WARN'
        [void]$stopEvent.Set()
        [void](Wait-NamedMutexToDisappear -Name $coordinationNames.HostMutex -TimeoutMilliseconds 3000)
        return 0
    }
    catch {
        Write-Log "Prep preload failed: $($_.Exception.Message). Continue will use the standalone fallback." 'ERROR'
        try {
            if ($null -ne $stopEvent) { [void]$stopEvent.Set() }
        }
        catch {}
        return 0
    }
    finally {
        Close-CoordinationHandles -ReadyEvent $readyEvent -ContinueEvent $continueEvent -StopEvent $stopEvent
    }
}

function Invoke-ContinueCommand {
    if (Test-StreamingCancellation) {
        $script:continueWasCancelled = $true
        Write-Log 'The preload session was cancelled with Alt+F4. Continue will exit without launching Playnite.'
        return $false
    }

    if (-not $streamingSettings.Enabled) {
        Write-Log 'Streaming integration is disabled. Continue will use standalone mode.' 'WARN'
        return $false
    }

    if (-not (Test-NamedMutexExists -Name $coordinationNames.HostMutex)) {
        if (Test-StreamingCancellation) {
            $script:continueWasCancelled = $true
            Write-Log 'The preload host closed after an Alt+F4 cancellation. Continue will not use the standalone fallback.'
            return $false
        }

        Write-Log 'No preload host was found.' 'WARN'
        return $false
    }

    $readyEvent = $null
    $continueEvent = $null
    $stopEvent = $null

    try {
        $readyEvent = New-CoordinationEvent -Name $coordinationNames.ReadyEvent
        $continueEvent = New-CoordinationEvent -Name $coordinationNames.ContinueEvent
        $stopEvent = New-CoordinationEvent -Name $coordinationNames.StopEvent

        if ($stopEvent.WaitOne(0)) {
            Write-Log 'The preload host is already stopping. Switching to fallback immediately.' 'WARN'
            return $false
        }

        if (-not $readyEvent.WaitOne($streamingSettings.ContinueWaitTimeoutMilliseconds)) {
            Write-Log "The preload host exists but did not become ready within $($streamingSettings.ContinueWaitTimeoutMilliseconds) ms." 'WARN'
            [void]$stopEvent.Set()
            return $false
        }

        if (Test-StreamingCancellation) {
            $script:continueWasCancelled = $true
            Write-Log 'The preload session was cancelled before Continue could launch Playnite.'
            return $false
        }

        [void]$continueEvent.Set()
        Write-Log 'Continue signal sent to the host. The Detached command can exit; the host will launch Playnite.'
        return $true
    }
    catch {
        Write-Log "Continue failed: $($_.Exception.Message)" 'ERROR'
        try {
            if ($null -ne $stopEvent) { [void]$stopEvent.Set() }
        }
        catch {}
        return $false
    }
    finally {
        Close-CoordinationHandles -ReadyEvent $readyEvent -ContinueEvent $continueEvent -StopEvent $stopEvent
    }
}

$coordinationNames = Get-CoordinationNames -Identity $ConfigPath

# Preload e Continue sono comandi brevi. Solo Standalone e Host proseguono fino
# alla creazione dell'overlay WPF.
if ($Mode -eq 'Preload') {
    exit (Invoke-PreloadCommand)
}

if ($Mode -eq 'Continue') {
    if (Invoke-ContinueCommand) {
        exit 0
    }

    if ($script:continueWasCancelled) {
        exit 0
    }

    # Se l'host e stato fermato, gli concediamo lo stesso intervallo della
    # baseline per rilasciare i mutex prima del fallback Standalone.
    [void](Wait-NamedMutexToDisappear -Name $coordinationNames.HostMutex -TimeoutMilliseconds 3000)

    if ($streamingSettings.FallbackMode.ToLowerInvariant() -eq 'standalone') {
        Write-Log 'Fallback A is active: starting the standalone baseline flow.' 'WARN'
        $Mode = 'Standalone'
    }
    else {
        Write-Log "Unsupported fallbackMode: '$($streamingSettings.FallbackMode)'." 'ERROR'
        exit 3
    }
}

# =============================================================================
# 4. Runtime Windows, monitor e finestra Playnite
# =============================================================================

function Get-ClientResolution {
    $widthValue = $env:SUNSHINE_CLIENT_WIDTH
    $heightValue = $env:SUNSHINE_CLIENT_HEIGHT

    if ([string]::IsNullOrWhiteSpace($widthValue)) {
        $widthValue = $env:APOLLO_CLIENT_WIDTH
    }
    if ([string]::IsNullOrWhiteSpace($heightValue)) {
        $heightValue = $env:APOLLO_CLIENT_HEIGHT
    }

    $width = 0
    $height = 0
    if ([int]::TryParse([string]$widthValue, [ref]$width) -and
        [int]::TryParse([string]$heightValue, [ref]$height) -and
        $width -gt 0 -and
        $height -gt 0) {
        return [PSCustomObject]@{
            Width = $width
            Height = $height
        }
    }

    return $null
}



$launcherMutex = $null
$launcherMutexAcquired = $false
$hostMutex = $null
$hostMutexAcquired = $false
$readyEvent = $null
$continueEvent = $null
$stopEvent = $null
$cursorHidden = $false

try {
    # La modalita Host e interna e possiede un mutex dedicato, distinto da
    # quello che impedisce due overlay contemporanei.
    if ($Mode -eq 'Host') {
        $hostMutex = [System.Threading.Mutex]::new($false, $coordinationNames.HostMutex)

        try {
            $hostMutexAcquired = $hostMutex.WaitOne(0)
        }
        catch [System.Threading.AbandonedMutexException] {
            # WaitOne assegna comunque il mutex al processo corrente quando
            # segnala che il proprietario precedente lo ha abbandonato.
            $hostMutexAcquired = $true
        }

        if (-not $hostMutexAcquired) {
            Write-Log 'Another preload host is already active. This process will exit.' 'WARN'
            exit 0
        }

        $readyEvent = New-CoordinationEvent -Name $coordinationNames.ReadyEvent
        $continueEvent = New-CoordinationEvent -Name $coordinationNames.ContinueEvent
        $stopEvent = New-CoordinationEvent -Name $coordinationNames.StopEvent
        Write-Log 'Preload host started and waiting to prepare the video.'
    }

    $launcherMutex = [System.Threading.Mutex]::new($false, $coordinationNames.LauncherMutex)

    try {
        $launcherMutexAcquired = $launcherMutex.WaitOne(0)
    }
    catch [System.Threading.AbandonedMutexException] {
        # Recupera correttamente il mutex dopo un launcher terminato in modo anomalo.
        $launcherMutexAcquired = $true
    }

    Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Threading;

public static class PlayniteBootNative
{
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [StructLayout(LayoutKind.Sequential)]
    private struct KBDLLHOOKSTRUCT
    {
        public uint vkCode;
        public uint scanCode;
        public uint flags;
        public uint time;
        public UIntPtr dwExtraInfo;
    }

    private delegate IntPtr LowLevelKeyboardProc(int nCode, IntPtr wParam, IntPtr lParam);

    public const int WmPlayniteBootAltF4 = 0x8504;
    public const int WmPlayniteBootAltTab = 0x8505;

    private const int WhKeyboardLl = 13;
    private const int HcAction = 0;
    private const int WmKeyDown = 0x0100;
    private const int WmSysKeyDown = 0x0104;
    private const uint VkTab = 0x09;
    private const uint VkF4 = 0x73;
    private const uint LlkhfAltDown = 0x20;

    private static IntPtr altF4Hook = IntPtr.Zero;
    private static IntPtr altF4TargetWindow = IntPtr.Zero;
    private static LowLevelKeyboardProc altF4HookProc;
    private static int altF4MessagePosted;
    private static int altTabMessagePosted;
    private static int lastAltF4HookError;

    public static int LastAltF4HookError
    {
        get { return lastAltF4HookError; }
    }

    [DllImport("user32.dll", SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(
        int idHook,
        LowLevelKeyboardProc lpfn,
        IntPtr hMod,
        uint dwThreadId
    );

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll")]
    private static extern IntPtr CallNextHookEx(
        IntPtr hhk,
        int nCode,
        IntPtr wParam,
        IntPtr lParam
    );

    [DllImport("user32.dll", SetLastError = true)]
    private static extern bool PostMessage(
        IntPtr hWnd,
        uint msg,
        IntPtr wParam,
        IntPtr lParam
    );

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string moduleName);

    public static bool InstallAltF4Hook(IntPtr targetWindow)
    {
        if (targetWindow == IntPtr.Zero)
        {
            lastAltF4HookError = 87;
            return false;
        }

        if (altF4Hook != IntPtr.Zero)
        {
            return true;
        }

        lastAltF4HookError = 0;
        altF4TargetWindow = targetWindow;
        Interlocked.Exchange(ref altF4MessagePosted, 0);
        Interlocked.Exchange(ref altTabMessagePosted, 0);
        altF4HookProc = AltF4HookCallback;

        IntPtr moduleHandle = GetModuleHandle(null);
        altF4Hook = SetWindowsHookEx(
            WhKeyboardLl,
            altF4HookProc,
            moduleHandle,
            0
        );

        if (altF4Hook == IntPtr.Zero)
        {
            lastAltF4HookError = Marshal.GetLastWin32Error();
            altF4TargetWindow = IntPtr.Zero;
            altF4HookProc = null;
            return false;
        }

        return true;
    }

    public static bool UninstallAltF4Hook()
    {
        IntPtr hook = altF4Hook;
        altF4Hook = IntPtr.Zero;
        altF4TargetWindow = IntPtr.Zero;
        Interlocked.Exchange(ref altF4MessagePosted, 0);
        Interlocked.Exchange(ref altTabMessagePosted, 0);

        bool removed = true;
        if (hook != IntPtr.Zero)
        {
            removed = UnhookWindowsHookEx(hook);
        }

        altF4HookProc = null;
        return removed;
    }

    private static IntPtr AltF4HookCallback(
        int nCode,
        IntPtr wParam,
        IntPtr lParam
    )
    {
        try
        {
            int message = wParam.ToInt32();
            if (nCode == HcAction &&
                (message == WmKeyDown || message == WmSysKeyDown))
            {
                KBDLLHOOKSTRUCT keyboardData = (KBDLLHOOKSTRUCT)Marshal.PtrToStructure(
                    lParam,
                    typeof(KBDLLHOOKSTRUCT)
                );

                bool altF4 = keyboardData.vkCode == VkF4 &&
                             (keyboardData.flags & LlkhfAltDown) != 0;
                bool altTab = keyboardData.vkCode == VkTab &&
                              (keyboardData.flags & LlkhfAltDown) != 0;

                if (altF4)
                {
                    if (Interlocked.Exchange(ref altF4MessagePosted, 1) == 0 &&
                        altF4TargetWindow != IntPtr.Zero)
                    {
                        PostMessage(
                            altF4TargetWindow,
                            WmPlayniteBootAltF4,
                            IntPtr.Zero,
                            IntPtr.Zero
                        );
                    }

                    // La cancellazione viene gestita una sola volta
                    // dall'overlay, che decide come arrestare Playnite.
                    return new IntPtr(1);
                }

                if (altTab)
                {
                    if (Interlocked.Exchange(ref altTabMessagePosted, 1) == 0 &&
                        altF4TargetWindow != IntPtr.Zero)
                    {
                        PostMessage(
                            altF4TargetWindow,
                            WmPlayniteBootAltTab,
                            IntPtr.Zero,
                            IntPtr.Zero
                        );
                    }

                    // Alt+Tab deve continuare verso Windows. Il messaggio
                    // personalizzato serve solo a demotare l'overlay.
                }
            }
        }
        catch
        {
        }

        return CallNextHookEx(altF4Hook, nCode, wParam, lParam);
    }

    [DllImport("user32.dll")]
    public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool SetProcessDPIAware();

    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
}
"@

    [void][PlayniteBootNative]::SetProcessDPIAware()

    # A transient Playnite window can have a valid MainWindowHandle and remain
    # visible long enough to look stable. The candidate must therefore cover at
    # least 85% of the monitor it actually occupies. The monitor is selected by
    # the largest intersection area, independently from the boot overlay.
    $minimumPlayniteMonitorCoverage = 0.85

    function Test-PlayniteWindowReady {
        param(
            [Parameter(Mandatory = $true)]
            $Process,

            [Parameter(Mandatory = $true)]
            $AvailableScreens,

            [Parameter(Mandatory = $true)]
            [double]$MinimumCoverage
        )

        try {
            if ($Process.HasExited) {
                return $null
            }

            $Process.Refresh()
            $windowHandle = $Process.MainWindowHandle
            if ($windowHandle -eq [IntPtr]::Zero) {
                return $null
            }

            if (-not [PlayniteBootNative]::IsWindowVisible($windowHandle)) {
                return $null
            }

            $windowRectangle = New-Object PlayniteBootNative+RECT
            if (-not [PlayniteBootNative]::GetWindowRect($windowHandle, [ref]$windowRectangle)) {
                return $null
            }

            $windowWidth = $windowRectangle.Right - $windowRectangle.Left
            $windowHeight = $windowRectangle.Bottom - $windowRectangle.Top
            if ($windowWidth -lt 200 -or $windowHeight -lt 120) {
                return $null
            }

            $bestScreen = $null
            $bestIntersectionArea = 0.0
            foreach ($screen in @($AvailableScreens)) {
                $bounds = $screen.Bounds
                $intersectionLeft = [Math]::Max($windowRectangle.Left, $bounds.Left)
                $intersectionTop = [Math]::Max($windowRectangle.Top, $bounds.Top)
                $intersectionRight = [Math]::Min($windowRectangle.Right, $bounds.Right)
                $intersectionBottom = [Math]::Min($windowRectangle.Bottom, $bounds.Bottom)

                $intersectionWidth = [Math]::Max(0, $intersectionRight - $intersectionLeft)
                $intersectionHeight = [Math]::Max(0, $intersectionBottom - $intersectionTop)
                $intersectionArea = [double]$intersectionWidth * [double]$intersectionHeight

                if ($intersectionArea -gt $bestIntersectionArea) {
                    $bestIntersectionArea = $intersectionArea
                    $bestScreen = $screen
                }
            }

            if ($null -eq $bestScreen) {
                return $null
            }

            $monitorArea = [double]$bestScreen.Bounds.Width * [double]$bestScreen.Bounds.Height
            if ($monitorArea -le 0) {
                return $null
            }

            $coverage = $bestIntersectionArea / $monitorArea
            if ($coverage -lt $MinimumCoverage) {
                return $null
            }

            return [PSCustomObject]@{
                Screen = $bestScreen
                Coverage = $coverage
                WindowHandle = $windowHandle
            }
        }
        catch {
            return $null
        }
    }

    function Activate-PlayniteWindow {
        param(
            [Parameter(Mandatory = $false)]
            $Process
        )

        if ($null -eq $Process) {
            return
        }

        try {
            if ($Process.HasExited) {
                return
            }

            $Process.Refresh()
            $windowHandle = $Process.MainWindowHandle
            if ($windowHandle -ne [IntPtr]::Zero) {
                # SW_RESTORE = 9. Ripristiniamo la finestra prima di chiedere il
                # foreground, come nella baseline originale.
                [void][PlayniteBootNative]::ShowWindowAsync($windowHandle, 9)
                [void][PlayniteBootNative]::SetForegroundWindow($windowHandle)
            }
        }
        catch {
            Write-Log "Could not bring Playnite to the foreground: $($_.Exception.Message)" 'WARN'
        }
    }

    if (-not $launcherMutexAcquired) {
        Write-Log 'Another launcher instance is already running. Bringing Playnite to the foreground and exiting.' 'WARN'
        Activate-PlayniteWindow -Process (Get-RunningFullscreenProcess)
        exit 0
    }

    $existingProcess = Get-RunningFullscreenProcess
    if ($null -ne $existingProcess) {
        Write-Log 'Playnite Fullscreen is already running. No new boot overlay will be shown.'
        Activate-PlayniteWindow -Process $existingProcess
        exit 0
    }

    # Parametri generali. I valori e i limiti sono gli stessi della baseline.
    $settings = [PSCustomObject]@{
        PlayniteExecutable = [string](Get-ConfigValue -Config $config -Name 'playniteExecutable' -DefaultValue 'auto')
        PlayniteConfigurationPath = [string](Get-ConfigValue -Config $config -Name 'playniteConfigurationPath' -DefaultValue '')
        LaunchArguments = [string](Get-ConfigValue -Config $config -Name 'launchArguments' -DefaultValue '--hidesplashscreen')
        VideoPath = $(Resolve-ConfiguredPath -Path ([string](Get-ConfigValue -Config $config -Name 'videoPath' -DefaultValue '.\media\boot-4k60.mp4')) -BaseDirectory $baseDirectory)
        Monitor = [string](Get-ConfigValue -Config $config -Name 'monitor' -DefaultValue 'playnite')
        MonitorFallback = [string](Get-ConfigValue -Config $config -Name 'monitorFallback' -DefaultValue 'primary')
        VideoStretch = [string](Get-ConfigValue -Config $config -Name 'videoStretch' -DefaultValue 'UniformToFill')
        LoopVideo = [bool](Get-ConfigValue -Config $config -Name 'loopVideo' -DefaultValue $false)
        WaitForVideoEnd = [bool](Get-ConfigValue -Config $config -Name 'waitForVideoEnd' -DefaultValue $false)
        Mute = [bool](Get-ConfigValue -Config $config -Name 'mute' -DefaultValue $true)
        Volume = $(Get-ClampedDouble -Value ([double](Get-ConfigValue -Config $config -Name 'volume' -DefaultValue 0.0)) -Minimum 0.0 -Maximum 1.0)

        MinimumVideoMilliseconds = $(Get-MinimumInteger -Value ([int](Get-ConfigValue -Config $config -Name 'minimumVideoMilliseconds' -DefaultValue 900)) -Minimum 0 -Fallback 0)
        ReadyStabilityMilliseconds = $(Get-MinimumInteger -Value ([int](Get-ConfigValue -Config $config -Name 'readyStabilityMilliseconds' -DefaultValue 500)) -Minimum 0 -Fallback 0)
        StartTimeoutSeconds = $(Get-MinimumInteger -Value ([int](Get-ConfigValue -Config $config -Name 'startTimeoutSeconds' -DefaultValue 45)) -Minimum 1 -Fallback 45)

        VideoReadyPositionMilliseconds = $(Get-MinimumInteger -Value ([int](Get-ConfigValue -Config $config -Name 'videoReadyPositionMilliseconds' -DefaultValue 180)) -Minimum 0 -Fallback 0)
        VideoReadyAdvanceSamples = $(Get-MinimumInteger -Value ([int](Get-ConfigValue -Config $config -Name 'videoReadyAdvanceSamples' -DefaultValue 3)) -Minimum 1 -Fallback 1)
        VideoReadyTimeoutMilliseconds = $(Get-MinimumInteger -Value ([int](Get-ConfigValue -Config $config -Name 'videoReadyTimeoutMilliseconds' -DefaultValue 5000)) -Minimum 1000 -Fallback 1000)

        FadeInMilliseconds = $(Get-MinimumInteger -Value ([int](Get-ConfigValue -Config $config -Name 'fadeInMilliseconds' -DefaultValue 80)) -Minimum 0 -Fallback 0)
        FadeOutMilliseconds = $(Get-MinimumInteger -Value ([int](Get-ConfigValue -Config $config -Name 'fadeOutMilliseconds' -DefaultValue 400)) -Minimum 0 -Fallback 0)
        HideMouseCursor = [bool](Get-ConfigValue -Config $config -Name 'hideMouseCursor' -DefaultValue $true)
    }

    if ($settings.WaitForVideoEnd -and $settings.LoopVideo) {
        throw 'Invalid configuration: loopVideo and waitForVideoEnd cannot both be enabled.'
    }

    $playniteExecutable = Find-PlayniteFullscreenExecutable -ConfiguredPath $settings.PlayniteExecutable -BaseDirectory $baseDirectory

    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Xaml
    Add-Type -AssemblyName System.Windows.Forms

    function Get-PlayniteConfiguredScreen {
        param(
            [Parameter(Mandatory = $false)]
            [string]$ConfigurationDirectory,

            [Parameter(Mandatory = $true)]
            $AvailableScreens
        )

        if ([string]::IsNullOrWhiteSpace($ConfigurationDirectory)) {
            Write-Log 'Playnite configuration path is unavailable. Follow Playnite will use the configured fallback monitor.' 'WARN'
            return $null
        }

        try {
            $fullscreenConfigPath = Join-Path -Path $ConfigurationDirectory -ChildPath 'fullscreenConfig.json'
            if (-not (Test-Path -LiteralPath $fullscreenConfigPath -PathType Leaf)) {
                Write-Log "Playnite Fullscreen configuration was not found at '$fullscreenConfigPath'. Using the configured fallback monitor." 'WARN'
                return $null
            }

            $fullscreenConfig = Get-Content -LiteralPath $fullscreenConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $usePrimaryDisplay = [bool](Get-ConfigValue -Config $fullscreenConfig -Name 'UsePrimaryDisplay' -DefaultValue $false)
            if ($usePrimaryDisplay) {
                $primary = [System.Windows.Forms.Screen]::PrimaryScreen
                if ($null -ne $primary) {
                    Write-Log "Follow Playnite selected the primary monitor: $($primary.DeviceName)."
                    return $primary
                }
            }

            $monitorIndex = [int](Get-ConfigValue -Config $fullscreenConfig -Name 'Monitor' -DefaultValue -1)
            if ($monitorIndex -ge 0 -and $monitorIndex -lt $AvailableScreens.Count) {
                $configuredScreen = $AvailableScreens[$monitorIndex]
                Write-Log "Follow Playnite selected monitor index $($monitorIndex): $($configuredScreen.DeviceName)."
                return $configuredScreen
            }

            Write-Log "Playnite Fullscreen monitor index $monitorIndex is not available. Using the configured fallback monitor." 'WARN'
            return $null
        }
        catch {
            Write-Log "Could not read Playnite Fullscreen display settings: $($_.Exception.Message). Using the configured fallback monitor." 'WARN'
            return $null
        }
    }

    function Select-ScreenByMode {
        param(
            [Parameter(Mandatory = $true)]
            [string]$SelectionMode,

            [Parameter(Mandatory = $true)]
            $AvailableScreens
        )

        if ([string]::IsNullOrWhiteSpace($SelectionMode)) {
            Write-Log 'Monitor mode is empty. A fallback monitor will be used.' 'WARN'
            return $null
        }

        switch -Regex ($SelectionMode.ToLowerInvariant()) {
            '^playnite$|^followplaynite$' {
                return Get-PlayniteConfiguredScreen -ConfigurationDirectory $settings.PlayniteConfigurationPath -AvailableScreens $AvailableScreens
            }
            '^primary$' {
                return [System.Windows.Forms.Screen]::PrimaryScreen
            }
            '^cursor$|^auto$' {
                $cursorScreen = [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position)
                if ($null -eq $cursorScreen) {
                    return [System.Windows.Forms.Screen]::PrimaryScreen
                }
                return $cursorScreen
            }
            '^index:(\d+)$' {
                $index = [int]$Matches[1]
                if ($index -ge 0 -and $index -lt $AvailableScreens.Count) {
                    return $AvailableScreens[$index]
                }
                Write-Log "Monitor index $index is not available. A fallback monitor will be used." 'WARN'
                return $null
            }
            '^clientresolution$|^client$' {
                $clientResolution = Get-ClientResolution
                if ($null -eq $clientResolution) {
                    Write-Log 'Client resolution is not available in SUNSHINE/APOLLO environment variables. Using the general monitor setting.' 'WARN'
                    return $null
                }

                $matchingScreens = @($AvailableScreens | Where-Object {
                    $_.Bounds.Width -eq $clientResolution.Width -and
                    $_.Bounds.Height -eq $clientResolution.Height
                })

                if ($matchingScreens.Count -eq 1) {
                    Write-Log "Streaming monitor matched by client resolution: $($clientResolution.Width)x$($clientResolution.Height)."
                    return $matchingScreens[0]
                }

                if ($matchingScreens.Count -gt 1) {
                    $cursorScreen = [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position)
                    $screenWithoutCursor = $matchingScreens |
                        Where-Object {
                            $null -eq $cursorScreen -or $_.DeviceName -ne $cursorScreen.DeviceName
                        } |
                        Select-Object -First 1

                    if ($null -ne $screenWithoutCursor) {
                        Write-Log "Multiple monitors match $($clientResolution.Width)x$($clientResolution.Height); selecting the one that does not contain the cursor: $($screenWithoutCursor.DeviceName)." 'WARN'
                        return $screenWithoutCursor
                    }

                    Write-Log "Multiple monitors match the client resolution; selecting the first one. Set streaming.monitor to index:N for deterministic selection." 'WARN'
                    return $matchingScreens[0]
                }

                Write-Log "No monitor matches the client resolution $($clientResolution.Width)x$($clientResolution.Height). Using the general monitor setting." 'WARN'
                return $null
            }
            default {
                Write-Log "Invalid monitor mode ('$SelectionMode'). Using the primary monitor." 'WARN'
                return [System.Windows.Forms.Screen]::PrimaryScreen
            }
        }
    }

    $screens = @([System.Windows.Forms.Screen]::AllScreens)
    if ($screens.Count -eq 0) {
        throw 'No monitors were detected.'
    }

    $selectedMonitorMode = $settings.Monitor
    if ($Mode -eq 'Host' -and
        -not [string]::IsNullOrWhiteSpace($streamingSettings.Monitor) -and
        $streamingSettings.Monitor.ToLowerInvariant() -ne 'inherit') {
        $selectedMonitorMode = $streamingSettings.Monitor
    }

    $selectedScreen = Select-ScreenByMode -SelectionMode $selectedMonitorMode -AvailableScreens $screens
    if ($null -eq $selectedScreen -and $selectedMonitorMode -ne $settings.Monitor) {
        $selectedScreen = Select-ScreenByMode -SelectionMode $settings.Monitor -AvailableScreens $screens
    }
    if ($null -eq $selectedScreen -and
        ($selectedMonitorMode -match '^(?i:playnite|followplaynite)$' -or
         $settings.Monitor -match '^(?i:playnite|followplaynite)$')) {
        Write-Log "Follow Playnite could not resolve a display. Falling back to '$($settings.MonitorFallback)'." 'WARN'
        $selectedScreen = Select-ScreenByMode -SelectionMode $settings.MonitorFallback -AvailableScreens $screens
    }
    if ($null -eq $selectedScreen) {
        $selectedScreen = [System.Windows.Forms.Screen]::PrimaryScreen
    }

    # L'overlay parte nero. Il MediaElement resta trasparente finche il clock
    # di riproduzione non avanza per il numero di campioni configurato.
    $xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None"
        ResizeMode="NoResize"
        ShowInTaskbar="False"
        Topmost="True"
        Background="Black"
        AllowsTransparency="False"
        Focusable="True"
        Opacity="1">
    <Grid Background="Black">
        <MediaElement x:Name="BootVideo"
                      LoadedBehavior="Manual"
                      UnloadedBehavior="Manual"
                      ScrubbingEnabled="True"
                      Stretch="UniformToFill"
                      Opacity="0" />
    </Grid>
</Window>
'@

    $xmlReader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
    $window = [Windows.Markup.XamlReader]::Load($xmlReader)
    $media = $window.FindName('BootVideo')

    $screenBounds = $selectedScreen.Bounds
    $window.WindowStartupLocation = [System.Windows.WindowStartupLocation]::Manual
    $window.Left = $screenBounds.Left
    $window.Top = $screenBounds.Top
    $window.Width = $screenBounds.Width
    $window.Height = $screenBounds.Height

    try {
        $media.Stretch = [System.Enum]::Parse([System.Windows.Media.Stretch], $settings.VideoStretch, $true)
    }
    catch {
        $media.Stretch = [System.Windows.Media.Stretch]::UniformToFill
        Write-Log "Invalid videoStretch ('$($settings.VideoStretch)'). Using UniformToFill." 'WARN'
    }

    if ($settings.Mute) {
        $media.Volume = 0.0
    }
    else {
        $media.Volume = $settings.Volume
    }

    $videoExists = Test-Path -LiteralPath $settings.VideoPath -PathType Leaf
    if ($videoExists) {
        $media.Source = New-Object System.Uri($settings.VideoPath, [System.UriKind]::Absolute)
    }
    else {
        Write-Log "Video not found: $($settings.VideoPath). A black background will be shown." 'WARN'
    }

    # =========================================================================
    # 5. Overlay video e stato WPF
    # =========================================================================

    # Stato condiviso dagli handler WPF. Le chiavi sono inizializzate in un
    # unico punto per rendere esplicito il ciclo di vita dell'overlay.
    $state = @{
        Process = $null
        ReadySince = $null
        ReadyProcessId = $null
        ReadyWindowHandle = [IntPtr]::Zero
        StartWatch = [Diagnostics.Stopwatch]::new()
        PreloadWatch = [Diagnostics.Stopwatch]::new()
        Closing = $false
        UserYieldedForeground = $false
        BootCancelled = $false
        AltF4HookInstalled = $false
        AltF4HookSource = $null
        AltF4WindowHook = $null
        ExitCode = 0
        WindowWasReady = $false
        PlayniteReady = $false
        MediaOpened = $false
        MediaOpenedAt = $null
        VideoRevealed = $false
        VideoRevealedAt = $null
        VideoEnded = $false
        VideoFailed = $false
        VideoEndFrameHeld = $false
        WaitingForVideoEndLogged = $false
        WaitingForPlayniteLogged = $false
        LastMediaPositionMs = -1
        AdvancingSamples = 0
        VideoReadyTimeoutLogged = $false
        VideoPlaybackWatch = [Diagnostics.Stopwatch]::new()
        PreloadReadySignaled = $false
        LaunchStarted = $false
    }

    $uninstallAltF4Hook = {
        if ($state.AltF4HookInstalled) {
            try {
                [void][PlayniteBootNative]::UninstallAltF4Hook()
            }
            catch {
            }
        }

        if ($null -ne $state.AltF4HookSource -and
            $null -ne $state.AltF4WindowHook) {
            try {
                $state.AltF4HookSource.RemoveHook($state.AltF4WindowHook)
            }
            catch {
            }
        }

        $state.AltF4HookInstalled = $false
        $state.AltF4HookSource = $null
        $state.AltF4WindowHook = $null
    }

    # Un vero Alt+Tab dell'utente cede esplicitamente il foreground. Non usiamo
    # il polling della finestra attiva: launcher, terminali e client streaming
    # possono diventare foreground durante Prep/Continue senza che l'utente
    # abbia chiesto di lasciare l'overlay.
    $yieldOverlayForAltTab = {
        if ($state.Closing -or $state.UserYieldedForeground) {
            return
        }

        $state.UserYieldedForeground = $true
        & $uninstallAltF4Hook
        $window.Topmost = $false

        # Cursor.Hide agisce globalmente: dopo un vero Alt+Tab il cursore deve
        # tornare immediatamente disponibile nell'app scelta dall'utente.
        if ($script:cursorHidden) {
            try {
                [System.Windows.Forms.Cursor]::Show()
                $script:cursorHidden = $false
            }
            catch {
            }
        }

        Write-Log 'Alt+Tab received. The overlay will continue in the background and will no longer intercept Alt+F4.'
    }

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(50)

    # Gli scriptblock seguenti sono callback WPF. Restano scriptblock, invece
    # di funzioni globali, per catturare in modo esplicito window, media e state.

    $signalPreloadReady = {
        if ($Mode -ne 'Host' -or $state.PreloadReadySignaled -or $null -eq $readyEvent) {
            return
        }

        $state.PreloadReadySignaled = $true
        [void]$readyEvent.Set()
        Write-Log 'Preload-ready signal sent: the video is visible and advancing.'
    }

    $revealVideo = {
        if ($state.VideoRevealed -or -not $videoExists -or $state.Closing) {
            return
        }

        $state.VideoRevealed = $true
        $state.VideoRevealedAt = [DateTime]::UtcNow
        $positionMilliseconds = [int]$media.Position.TotalMilliseconds

        if ($settings.FadeInMilliseconds -le 0) {
            $media.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
            $media.Opacity = 1.0
            Write-Log "Video revealed at $positionMilliseconds ms after $($state.AdvancingSamples) advancing samples."
            return
        }

        $fadeInAnimation = New-Object System.Windows.Media.Animation.DoubleAnimation
        $fadeInAnimation.From = 0.0
        $fadeInAnimation.To = 1.0
        $fadeInAnimation.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds($settings.FadeInMilliseconds))
        $fadeInAnimation.FillBehavior = [System.Windows.Media.Animation.FillBehavior]::HoldEnd
        $media.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $fadeInAnimation)
        Write-Log "Video micro fade-in started at $positionMilliseconds ms after $($state.AdvancingSamples) advancing samples."
    }

    $holdLastVideoFrame = {
        if (-not $videoExists -or $state.VideoEndFrameHeld -or $state.Closing) {
            return
        }

        try {
            $holdPosition = $media.Position
            if ($media.NaturalDuration.HasTimeSpan) {
                $duration = $media.NaturalDuration.TimeSpan
                $frameOffsetMilliseconds = [Math]::Min(33.0, [Math]::Max(1.0, $duration.TotalMilliseconds))
                $holdPosition = $duration - [TimeSpan]::FromMilliseconds($frameOffsetMilliseconds)
                if ($holdPosition -lt [TimeSpan]::Zero) {
                    $holdPosition = [TimeSpan]::Zero
                }
            }
            elseif ($holdPosition.TotalMilliseconds -gt 33) {
                $holdPosition = $holdPosition - [TimeSpan]::FromMilliseconds(33)
            }

            $media.Position = $holdPosition
            $media.Pause()
            $state.VideoEndFrameHeld = $true
            Write-Log "Holding the final video frame at $([int]$holdPosition.TotalMilliseconds) ms while waiting for Playnite."
        }
        catch {
            try { $media.Pause() } catch {}
            Write-Log "Could not seek explicitly to the final frame: $($_.Exception.Message)" 'WARN'
        }
    }

    $media.Add_MediaOpened({
        $state.MediaOpened = $true
        $state.MediaOpenedAt = [DateTime]::UtcNow
        Write-Log "Video opened and prerolling: $($settings.VideoPath)"
    })

    $media.Add_MediaEnded({
        if ($settings.LoopVideo -and -not $state.Closing) {
            $media.Position = [TimeSpan]::Zero
            $media.Play()
            return
        }

        if (-not $settings.WaitForVideoEnd) {
            $media.Pause()
            return
        }

        $state.VideoEnded = $true
        & $holdLastVideoFrame

        if (-not $state.VideoRevealed -and $videoExists) {
            & $revealVideo
        }

        if ($state.PlayniteReady) {
            Write-Log 'Video ended and Playnite is already ready. Fade-out will start on the next UI cycle.'
        }
        elseif (-not $state.WaitingForPlayniteLogged) {
            $state.WaitingForPlayniteLogged = $true
            Write-Log 'Video ended. Holding the final frame while waiting for Playnite.'
        }
    })

    $media.Add_MediaFailed({
        param($sender, $eventArgs)
        $state.VideoFailed = $true
        Write-Log "Video playback failed: $($eventArgs.ErrorException.Message). Using the Playnite-readiness fallback." 'WARN'
    })

    $closeImmediately = {
        param(
            [int]$ExitCode = 0
        )

        if ($state.Closing) {
            return
        }

        $state.Closing = $true
        $state.ExitCode = $ExitCode
        & $uninstallAltF4Hook
        $timer.Stop()
        try { $media.Stop() } catch {}
        $window.Close()
    }

    $stopPlayniteFullscreen = {
        $candidateProcesses = @()

        if ($null -ne $state.Process) {
            $candidateProcesses += $state.Process
        }

        $candidateProcesses += @(Get-Process -Name 'Playnite.FullscreenApp' -ErrorAction SilentlyContinue)
        $candidateProcesses = @(
            $candidateProcesses |
                Where-Object { $null -ne $_ } |
                Sort-Object -Property Id -Unique
        )

        if ($candidateProcesses.Count -eq 0) {
            Write-Log 'Alt+F4 cancellation found no running Playnite Fullscreen process.'
            return
        }

        foreach ($candidateProcess in $candidateProcesses) {
            try {
                $candidateProcess.Refresh()
                if ($candidateProcess.HasExited) {
                    continue
                }

                $processId = [int]$candidateProcess.Id
                if ($candidateProcess.MainWindowHandle -ne [IntPtr]::Zero -and
                    $candidateProcess.CloseMainWindow()) {
                    Write-Log "Requested a graceful shutdown of Playnite Fullscreen PID $processId."
                }
                else {
                    Write-Log "Playnite Fullscreen PID $processId has no closable main window yet; waiting briefly before termination." 'WARN'
                }
            }
            catch {
                Write-Log "Could not request a graceful Playnite Fullscreen shutdown: $($_.Exception.Message)" 'WARN'
            }
        }

        $gracefulDeadline = [DateTime]::UtcNow.AddMilliseconds(1500)
        do {
            $runningProcesses = @()
            foreach ($candidateProcess in $candidateProcesses) {
                try {
                    $candidateProcess.Refresh()
                    if (-not $candidateProcess.HasExited) {
                        $runningProcesses += $candidateProcess
                    }
                }
                catch {
                }
            }

            if ($runningProcesses.Count -eq 0 -or
                [DateTime]::UtcNow -ge $gracefulDeadline) {
                break
            }

            Start-Sleep -Milliseconds 100
        } while ($true)

        foreach ($candidateProcess in $runningProcesses) {
            try {
                $candidateProcess.Refresh()
                if ($candidateProcess.HasExited) {
                    continue
                }

                $processId = [int]$candidateProcess.Id
                Write-Log "Playnite Fullscreen PID $processId did not exit gracefully; terminating it." 'WARN'
                $candidateProcess.Kill()
                [void]$candidateProcess.WaitForExit(1000)
            }
            catch {
                Write-Log "Could not terminate Playnite Fullscreen: $($_.Exception.Message)" 'ERROR'
            }
        }
    }

    $handleAltF4 = {
        if ($state.Closing -or $state.UserYieldedForeground) {
            return
        }

        $state.BootCancelled = $true

        if ($Mode -eq 'Host') {
            Set-StreamingCancellation
        }

        if ($state.LaunchStarted) {
            Write-Log 'Alt+F4 received. Cancelling the boot sequence and stopping Playnite Fullscreen.'
            & $stopPlayniteFullscreen
        }
        else {
            Write-Log 'Alt+F4 received. Cancelling the boot sequence before Playnite launch.'
        }

        & $closeImmediately 0
    }

    $handleAltTab = {
        & $yieldOverlayForAltTab
    }

    # Fallback quando l'overlay possiede direttamente il focus della tastiera.
    $window.Add_PreviewKeyDown({
        param($sender, $eventArgs)

        $altPressed = (
            ([System.Windows.Input.Keyboard]::Modifiers -band
                [System.Windows.Input.ModifierKeys]::Alt) -ne
            [System.Windows.Input.ModifierKeys]::None
        )
        $isAltF4 = (
            $eventArgs.Key -eq [System.Windows.Input.Key]::System -and
            $eventArgs.SystemKey -eq [System.Windows.Input.Key]::F4
        ) -or (
            $altPressed -and
            $eventArgs.Key -eq [System.Windows.Input.Key]::F4
        )

        $isAltTab = $altPressed -and (
            $eventArgs.Key -eq [System.Windows.Input.Key]::Tab -or
            $eventArgs.SystemKey -eq [System.Windows.Input.Key]::Tab
        )

        if ($isAltTab) {
            # Non impostiamo Handled: Windows deve completare normalmente
            # il cambio applicazione richiesto dall'utente.
            & $handleAltTab
            return
        }

        if ($isAltF4) {
            $eventArgs.Handled = $true
            & $handleAltF4
        }
    })

    $installAltF4Hook = {
        if ($state.Closing -or
            $state.UserYieldedForeground -or
            $state.AltF4HookInstalled) {
            return
        }

        try {
            $interopHelper = New-Object System.Windows.Interop.WindowInteropHelper($window)
            $windowHandle = $interopHelper.Handle
            if ($windowHandle -eq [IntPtr]::Zero) {
                throw 'The overlay window handle is not available.'
            }

            $source = [System.Windows.Interop.HwndSource]::FromHwnd($windowHandle)
            if ($null -eq $source) {
                throw 'The WPF window message source is not available.'
            }

            $windowHook = [System.Windows.Interop.HwndSourceHook]{
                param($hwnd, $message, $wParam, $lParam, [ref]$handled)

                if ($message -eq [PlayniteBootNative]::WmPlayniteBootAltF4) {
                    $handled.Value = $true
                    & $handleAltF4
                }
                elseif ($message -eq [PlayniteBootNative]::WmPlayniteBootAltTab) {
                    $handled.Value = $true
                    & $handleAltTab
                }

                return [IntPtr]::Zero
            }

            $source.AddHook($windowHook)
            $installed = [PlayniteBootNative]::InstallAltF4Hook($windowHandle)

            if (-not $installed) {
                $source.RemoveHook($windowHook)
                $errorCode = [PlayniteBootNative]::LastAltF4HookError
                Write-Log "Alt+F4/Alt+Tab keyboard hook installation failed with Win32 error $errorCode. The focused-window fallback remains active." 'WARN'
                return
            }

            $state.AltF4HookInstalled = $true
            $state.AltF4HookSource = $source
            $state.AltF4WindowHook = $windowHook
            Write-Log 'Alt+F4 and Alt+Tab keyboard hook enabled for the active boot overlay.'
        }
        catch {
            try {
                [void][PlayniteBootNative]::UninstallAltF4Hook()
            }
            catch {
            }

            Write-Log "Could not enable Alt+F4/Alt+Tab support: $($_.Exception.Message)" 'WARN'
        }
    }

    $closeOverlayWithFade = {
        if ($state.Closing) {
            return
        }

        $state.Closing = $true
        & $uninstallAltF4Hook
        $timer.Stop()

        $candidateProcess = $state.Process
        if ($null -eq $candidateProcess -or $candidateProcess.HasExited) {
            $candidateProcess = Get-RunningFullscreenProcess
            $state.Process = $candidateProcess
        }

        if (-not $state.UserYieldedForeground) {
            Activate-PlayniteWindow -Process $candidateProcess
        }

        if ($settings.FadeOutMilliseconds -le 0) {
            try { $media.Stop() } catch {}
            $window.Close()
            return
        }

        Write-Log "Starting final fade-out ($($settings.FadeOutMilliseconds) ms)."
        $fadeOutAnimation = New-Object System.Windows.Media.Animation.DoubleAnimation
        $fadeOutAnimation.From = $window.Opacity
        $fadeOutAnimation.To = 0.0
        $fadeOutAnimation.Duration = [System.Windows.Duration]::new([TimeSpan]::FromMilliseconds($settings.FadeOutMilliseconds))
        $fadeOutAnimation.FillBehavior = [System.Windows.Media.Animation.FillBehavior]::Stop
        $fadeOutAnimation.Add_Completed({
            try { $media.Stop() } catch {}
            $window.Opacity = 0
            $window.Close()
        })
        $window.BeginAnimation([System.Windows.Window]::OpacityProperty, $fadeOutAnimation)
    }

    # =========================================================================
    # 6. Avvio e rilevamento di Playnite
    # =========================================================================

    $startPlaynite = {
        if ($state.LaunchStarted -or $state.Closing) {
            return
        }

        try {
            $processInfo = New-Object System.Diagnostics.ProcessStartInfo
            $processInfo.FileName = $playniteExecutable
            $processInfo.Arguments = $settings.LaunchArguments
            $processInfo.WorkingDirectory = Split-Path -Parent $playniteExecutable
            $processInfo.UseShellExecute = $true

            Write-Log "Launching: $playniteExecutable $($settings.LaunchArguments)"
            $state.Process = [System.Diagnostics.Process]::Start($processInfo)
            $state.LaunchStarted = $true
            $state.StartWatch.Restart()
        }
        catch {
            $state.ExitCode = 1
            Write-Log "Failed to launch Playnite: $($_.Exception.Message)" 'ERROR'
            & $closeOverlayWithFade
        }
    }

    $timer.Add_Tick({
        if ($state.Closing) {
            return
        }

        # Il segnale Stop viene usato solo per chiudere un host di preload che
        # non e riuscito o che non deve piu proseguire.
        if ($Mode -eq 'Host' -and $null -ne $stopEvent -and $stopEvent.WaitOne(0)) {
            Write-Log 'Stop signal received from Prep/Continue. Closing the host immediately.' 'WARN'
            & $closeImmediately 0
            return
        }

        # Il video viene rivelato soltanto quando il clock avanza in piu
        # campioni consecutivi: evita di mostrare il primo frame statico mentre
        # Media Foundation inizializza il decoder.
        if ($videoExists -and -not $state.VideoRevealed -and -not $state.VideoEnded) {
            if ($state.MediaOpened) {
                $positionMilliseconds = [int]$media.Position.TotalMilliseconds
                $lastPositionMilliseconds = [int]$state.LastMediaPositionMs

                if ($lastPositionMilliseconds -ge 0 -and
                    $positionMilliseconds -gt ($lastPositionMilliseconds + 1)) {
                    $state.AdvancingSamples = [int]$state.AdvancingSamples + 1
                }
                elseif ($positionMilliseconds -le $lastPositionMilliseconds) {
                    $state.AdvancingSamples = 0
                }

                $state.LastMediaPositionMs = $positionMilliseconds

                if ($positionMilliseconds -ge $settings.VideoReadyPositionMilliseconds -and
                    $state.AdvancingSamples -ge $settings.VideoReadyAdvanceSamples) {
                    & $revealVideo
                }
            }

            $videoWaitingMilliseconds = $state.VideoPlaybackWatch.ElapsedMilliseconds
            if ($videoWaitingMilliseconds -ge $settings.VideoReadyTimeoutMilliseconds -and
                -not $state.VideoReadyTimeoutLogged) {
                $state.VideoReadyTimeoutLogged = $true
                Write-Log "The video did not show reliable advancement within $($settings.VideoReadyTimeoutMilliseconds) ms. Keeping the black background to avoid a frozen frame." 'WARN'

                if ($settings.WaitForVideoEnd) {
                    $state.VideoFailed = $true
                    Write-Log 'Wait-for-video-end was disabled for this run because the decoder did not produce reliable playback.' 'WARN'
                }
            }
        }

        # Preload puo terminare solo dopo che il video e visibile per un breve
        # intervallo, cosi lo stream non riceve un frame non ancora renderizzato.
        if ($Mode -eq 'Host' -and
            $state.VideoRevealed -and
            -not $state.PreloadReadySignaled) {
            $visibleMilliseconds = ([DateTime]::UtcNow - $state.VideoRevealedAt).TotalMilliseconds
            $requiredVisibleMilliseconds = [Math]::Max(100, $settings.FadeInMilliseconds + 50)
            if ($visibleMilliseconds -ge $requiredVisibleMilliseconds) {
                & $signalPreloadReady
            }
        }

        # In Host il video viene preparato prima; Playnite parte solo dopo il
        # segnale inviato dal Detached command Continue.
        if ($Mode -eq 'Host' -and -not $state.LaunchStarted) {
            if ($null -ne $continueEvent -and $continueEvent.WaitOne(0)) {
                Write-Log 'Continue signal received: launching Playnite behind the preloaded overlay.'
                & $startPlaynite
            }
            elseif ($state.PreloadWatch.ElapsedMilliseconds -ge $streamingSettings.PreloadAbandonTimeoutMilliseconds) {
                Write-Log "No Continue signal was received within $($streamingSettings.PreloadAbandonTimeoutMilliseconds) ms. Closing the host to avoid a leftover process." 'WARN'
                & $closeImmediately 3
            }

            return
        }

        if (-not $state.LaunchStarted) {
            return
        }

        $candidateProcess = $null
        if ($null -ne $state.Process) {
            try {
                if (-not $state.Process.HasExited) {
                    $state.Process.Refresh()
                    $candidateProcess = $state.Process
                }
            }
            catch {
                $candidateProcess = $null
            }
        }

        if ($null -eq $candidateProcess) {
            $candidateProcess = Get-RunningFullscreenProcess
            if ($null -ne $candidateProcess) {
                $state.Process = $candidateProcess
            }
        }

        $windowReadiness = $null
        if ($null -ne $candidateProcess) {
            $windowReadiness = Test-PlayniteWindowReady -Process $candidateProcess -AvailableScreens $screens -MinimumCoverage $minimumPlayniteMonitorCoverage
        }
        $windowIsReady = $null -ne $windowReadiness

        $candidateProcessId = $null
        $candidateWindowHandle = [IntPtr]::Zero

        if ($windowIsReady) {
            try {
                $candidateProcess.Refresh()
                $candidateProcessId = [int]$candidateProcess.Id
                $candidateWindowHandle = [IntPtr]$candidateProcess.MainWindowHandle

                if ($candidateWindowHandle -eq [IntPtr]::Zero) {
                    $windowIsReady = $false
                }
            }
            catch {
                $windowIsReady = $false
            }
        }

        if ($settings.WaitForVideoEnd) {
            # In questa modalita la readiness diventa persistente: una volta
            # riconosciuta Playnite, il timeout si ferma e l overlay puo restare
            # attivo per tutta la durata di un video lungo.
            if (-not $state.PlayniteReady) {
                if ($windowIsReady) {
                    if ($null -eq $state.ReadySince -or
                        $state.ReadyProcessId -ne $candidateProcessId -or
                        $state.ReadyWindowHandle -ne $candidateWindowHandle) {

                        $state.ReadySince = [DateTime]::UtcNow
                        $state.ReadyProcessId = $candidateProcessId
                        $state.ReadyWindowHandle = $candidateWindowHandle
                        $coveragePercent = [Math]::Round($windowReadiness.Coverage * 100.0, 1)
                        $playniteScreenName = $windowReadiness.Screen.DeviceName
                        Write-Log "Fullscreen window detected for PID ${candidateProcessId} on ${playniteScreenName}: monitor coverage is ${coveragePercent}%."
                        if ($playniteScreenName -ne $selectedScreen.DeviceName) {
                            Write-Log "Playnite Fullscreen is on ${playniteScreenName} while the boot overlay is on $($selectedScreen.DeviceName). The overlay will close normally." 'WARN'
                        }
                    }

                    $stableMilliseconds = ([DateTime]::UtcNow - $state.ReadySince).TotalMilliseconds
                    if ($stableMilliseconds -ge $settings.ReadyStabilityMilliseconds) {
                        $state.PlayniteReady = $true
                        $state.WindowWasReady = $true
                        Write-Log "Playnite is ready: the window was stable for $([int]$stableMilliseconds) ms. The startup timeout is no longer evaluated."
                    }
                }
                else {
                    $state.ReadySince = $null
                    $state.ReadyProcessId = $null
                    $state.ReadyWindowHandle = [IntPtr]::Zero
                }
            }

            if ($state.PlayniteReady) {
                $videoCompletionRequired = $videoExists -and -not $state.VideoFailed
                if ($videoCompletionRequired) {
                    if ($state.VideoEnded) {
                        Write-Log 'Completion conditions met: Playnite is ready and the video has ended.'
                        & $closeOverlayWithFade
                        return
                    }

                    if (-not $state.WaitingForVideoEndLogged) {
                        $state.WaitingForVideoEndLogged = $true
                        Write-Log 'Playnite is ready. Waiting for the video to end naturally before fade-out.'
                    }
                }
                elseif ($state.StartWatch.ElapsedMilliseconds -ge $settings.MinimumVideoMilliseconds) {
                    Write-Log 'Video is missing or not playable. Applying the Playnite-readiness fallback.' 'WARN'
                    & $closeOverlayWithFade
                    return
                }
            }

            if (-not $state.PlayniteReady -and
                $state.StartWatch.Elapsed.TotalSeconds -ge $settings.StartTimeoutSeconds) {
                $state.ExitCode = 2
                Write-Log "Timed out after $($settings.StartTimeoutSeconds) seconds while waiting for the Fullscreen window." 'ERROR'
                & $closeOverlayWithFade
            }

            return
        }

        # Comportamento storico: rimane identico quando waitForVideoEnd e false.
        if ($windowIsReady) {
            if ($null -eq $state.ReadySince -or
                $state.ReadyProcessId -ne $candidateProcessId -or
                $state.ReadyWindowHandle -ne $candidateWindowHandle) {

                $state.ReadySince = [DateTime]::UtcNow
                $state.ReadyProcessId = $candidateProcessId
                $state.ReadyWindowHandle = $candidateWindowHandle
                $coveragePercent = [Math]::Round($windowReadiness.Coverage * 100.0, 1)
                $playniteScreenName = $windowReadiness.Screen.DeviceName
                Write-Log "Fullscreen window detected for PID ${candidateProcessId} on ${playniteScreenName}: monitor coverage is ${coveragePercent}%."
                if ($playniteScreenName -ne $selectedScreen.DeviceName) {
                    Write-Log "Playnite Fullscreen is on ${playniteScreenName} while the boot overlay is on $($selectedScreen.DeviceName). The overlay will close normally." 'WARN'
                }
            }

            $stableMilliseconds = ([DateTime]::UtcNow - $state.ReadySince).TotalMilliseconds
            if ($stableMilliseconds -ge $settings.ReadyStabilityMilliseconds -and
                $state.StartWatch.ElapsedMilliseconds -ge $settings.MinimumVideoMilliseconds) {
                $state.WindowWasReady = $true
                Write-Log "Playnite is ready: the window was stable for $([int]$stableMilliseconds) ms."
                & $closeOverlayWithFade
                return
            }
        }
        else {
            $state.ReadySince = $null
            $state.ReadyProcessId = $null
            $state.ReadyWindowHandle = [IntPtr]::Zero
        }

        if ($state.StartWatch.Elapsed.TotalSeconds -ge $settings.StartTimeoutSeconds) {
            $state.ExitCode = 2
            Write-Log "Timed out after $($settings.StartTimeoutSeconds) seconds while waiting for the Fullscreen window." 'ERROR'
            & $closeOverlayWithFade
        }
    })

    $window.Add_ContentRendered({
        try {
            if ($settings.HideMouseCursor) {
                [System.Windows.Forms.Cursor]::Hide()
                $script:cursorHidden = $true
            }

            $window.Activate() | Out-Null
            & $installAltF4Hook
            if ($videoExists) {
                $state.VideoPlaybackWatch.Restart()
                $media.Play()
            }

            Write-Log "Video: $($settings.VideoPath); adaptive ready position $($settings.VideoReadyPositionMilliseconds) ms; samples $($settings.VideoReadyAdvanceSamples); fade-in $($settings.FadeInMilliseconds) ms; fade-out $($settings.FadeOutMilliseconds) ms; wait for video end $($settings.WaitForVideoEnd)."
            Write-Log "Monitor: $($selectedScreen.DeviceName), bounds $($screenBounds.Left),$($screenBounds.Top) $($screenBounds.Width)x$($screenBounds.Height); selection '$selectedMonitorMode'."

            $timer.Start()
            if ($Mode -eq 'Host') {
                $state.PreloadWatch.Restart()
                Write-Log "Preload overlay displayed. Waiting for video-ready and then Continue for up to $($streamingSettings.PreloadAbandonTimeoutMilliseconds) ms."
            }
            else {
                & $startPlaynite
            }
        }
        catch {
            $state.ExitCode = 1
            Write-Log "Initialization failed: $($_.Exception.Message)" 'ERROR'
            & $closeImmediately 1
        }
    })

    $window.Add_Closed({
        & $uninstallAltF4Hook
        $timer.Stop()
        try { $media.Stop() } catch {}
    })

    [void]$window.ShowDialog()

    if ($cursorHidden) {
        [System.Windows.Forms.Cursor]::Show()
        $cursorHidden = $false
    }

    $trackedProcess = $state.Process
    if ($null -eq $trackedProcess -or $trackedProcess.HasExited) {
        $trackedProcess = Get-RunningFullscreenProcess
    }

    if ($state.WindowWasReady -and
        -not $state.UserYieldedForeground -and
        -not $state.BootCancelled) {
        Activate-PlayniteWindow -Process $trackedProcess
    }

    if ($state.BootCancelled) {
        Write-Log "Launcher exited with code $($state.ExitCode) after boot cancellation."
    }
    else {
        Write-Log "Launcher exited with code $($state.ExitCode). Playnite continues as an independent process."
    }
    exit ([int]$state.ExitCode)
}
catch {
    Write-Log $_.Exception.Message 'ERROR'
    throw
}
finally {
    # =========================================================================
    # 7. Cleanup
    # =========================================================================

    if ($cursorHidden) {
        try { [System.Windows.Forms.Cursor]::Show() } catch {}
    }

    if ($launcherMutexAcquired -and $null -ne $launcherMutex) {
        try { $launcherMutex.ReleaseMutex() } catch {}
    }
    if ($null -ne $launcherMutex) {
        $launcherMutex.Dispose()
    }

    if ($hostMutexAcquired -and $null -ne $hostMutex) {
        try { $hostMutex.ReleaseMutex() } catch {}
    }
    if ($null -ne $hostMutex) {
        $hostMutex.Dispose()
    }

    Close-CoordinationHandles -ReadyEvent $readyEvent -ContinueEvent $continueEvent -StopEvent $stopEvent
}
