[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $true)]
    [string]$RuntimeScriptPath,

    [Parameter(Mandatory = $true)]
    [string]$SwitchReadyEventName,

    [Parameter(Mandatory = $false)]
    [long]$SwitchStartUtcTicks = 0
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Get-PropertyValue {
    param(
        [Parameter(Mandatory = $false)]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $false)]$DefaultValue
    )

    if ($null -eq $Object) {
        return $DefaultValue
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $DefaultValue
    }

    return $property.Value
}

function Initialize-BootstrapNativeMethods {
    if ('PlayniteBootSwitchBootstrap.Native' -as [type]) {
        return
    }

    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace PlayniteBootSwitchBootstrap
{
    public static class Native
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct DEVMODE
        {
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            public string dmDeviceName;
            public ushort dmSpecVersion;
            public ushort dmDriverVersion;
            public ushort dmSize;
            public ushort dmDriverExtra;
            public uint dmFields;
            public int dmPositionX;
            public int dmPositionY;
            public uint dmDisplayOrientation;
            public uint dmDisplayFixedOutput;
            public short dmColor;
            public short dmDuplex;
            public short dmYResolution;
            public short dmTTOption;
            public short dmCollate;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            public string dmFormName;
            public ushort dmLogPixels;
            public uint dmBitsPerPel;
            public uint dmPelsWidth;
            public uint dmPelsHeight;
            public uint dmDisplayFlags;
            public uint dmDisplayFrequency;
            public uint dmICMMethod;
            public uint dmICMIntent;
            public uint dmMediaType;
            public uint dmDitherType;
            public uint dmReserved1;
            public uint dmReserved2;
            public uint dmPanningWidth;
            public uint dmPanningHeight;
        }

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool EnumDisplaySettingsEx(
            string lpszDeviceName,
            int iModeNum,
            ref DEVMODE lpDevMode,
            uint dwFlags);

        [DllImport("user32.dll")]
        public static extern IntPtr SetThreadDpiAwarenessContext(IntPtr dpiContext);
    }
}
'@
}

function Get-PhysicalDisplayBounds {
    param(
        [Parameter(Mandatory = $true)]$Screen
    )

    try {
        Initialize-BootstrapNativeMethods

        $mode = New-Object PlayniteBootSwitchBootstrap.Native+DEVMODE
        $mode.dmSize = [uint16][Runtime.InteropServices.Marshal]::SizeOf([type][PlayniteBootSwitchBootstrap.Native+DEVMODE])

        $enumCurrentSettings = -1
        $ok = [PlayniteBootSwitchBootstrap.Native]::EnumDisplaySettingsEx(
            [string]$Screen.DeviceName,
            $enumCurrentSettings,
            [ref]$mode,
            0)

        if (-not $ok -or $mode.dmPelsWidth -eq 0 -or $mode.dmPelsHeight -eq 0) {
            return $null
        }

        return New-Object System.Drawing.Rectangle(
            [int]$mode.dmPositionX,
            [int]$mode.dmPositionY,
            [int]$mode.dmPelsWidth,
            [int]$mode.dmPelsHeight)
    }
    catch {
        return $null
    }
}

function Select-BootstrapScreen {
    param(
        [Parameter(Mandatory = $true)]$Config,
        [Parameter(Mandatory = $true)]$Screens
    )

    $selectionMode = [string](Get-PropertyValue -Object $Config -Name 'monitor' -DefaultValue 'playnite')
    $fallbackMode = [string](Get-PropertyValue -Object $Config -Name 'monitorFallback' -DefaultValue 'primary')

    $selectByMode = {
        param([string]$Mode)

        if ([string]::IsNullOrWhiteSpace($Mode)) {
            return $null
        }

        switch -Regex ($Mode.ToLowerInvariant()) {
            '^playnite$|^followplaynite$' {
                $configurationDirectory = [string](Get-PropertyValue -Object $Config -Name 'playniteConfigurationPath' -DefaultValue '')
                if (-not [string]::IsNullOrWhiteSpace($configurationDirectory)) {
                    try {
                        $fullscreenConfigPath = Join-Path $configurationDirectory 'fullscreenConfig.json'
                        if (Test-Path -LiteralPath $fullscreenConfigPath -PathType Leaf) {
                            $fullscreenConfig = Get-Content -LiteralPath $fullscreenConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
                            $usePrimary = [bool](Get-PropertyValue -Object $fullscreenConfig -Name 'UsePrimaryDisplay' -DefaultValue $false)
                            if ($usePrimary) {
                                return [System.Windows.Forms.Screen]::PrimaryScreen
                            }

                            $monitorIndex = [int](Get-PropertyValue -Object $fullscreenConfig -Name 'Monitor' -DefaultValue -1)
                            if ($monitorIndex -ge 0 -and $monitorIndex -lt $Screens.Count) {
                                return $Screens[$monitorIndex]
                            }
                        }
                    }
                    catch {
                    }
                }

                return $null
            }
            '^primary$' {
                return [System.Windows.Forms.Screen]::PrimaryScreen
            }
            '^cursor$|^auto$' {
                return [System.Windows.Forms.Screen]::FromPoint([System.Windows.Forms.Cursor]::Position)
            }
            '^index:(\d+)$' {
                $index = [int]$Matches[1]
                if ($index -ge 0 -and $index -lt $Screens.Count) {
                    return $Screens[$index]
                }
                return $null
            }
            default {
                return $null
            }
        }
    }

    $selected = & $selectByMode $selectionMode
    if ($null -eq $selected -and $selectionMode -match '^(?i:playnite|followplaynite)$') {
        $selected = & $selectByMode $fallbackMode
    }
    if ($null -eq $selected) {
        $selected = [System.Windows.Forms.Screen]::PrimaryScreen
    }

    return $selected
}

$readyEvent = $null
$form = $null
try {
    $ConfigPath = [IO.Path]::GetFullPath($ConfigPath)
    $RuntimeScriptPath = [IO.Path]::GetFullPath($RuntimeScriptPath)

    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        throw "Configuration file not found: $ConfigPath"
    }
    if (-not (Test-Path -LiteralPath $RuntimeScriptPath -PathType Leaf)) {
        throw "Runtime script not found: $RuntimeScriptPath"
    }

    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    $config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $screens = @([System.Windows.Forms.Screen]::AllScreens)
    if ($screens.Count -eq 0) {
        throw 'No monitors were detected.'
    }

    $selectedScreen = Select-BootstrapScreen -Config $config -Screens $screens
    if ($null -eq $selectedScreen) {
        $selectedScreen = [System.Windows.Forms.Screen]::PrimaryScreen
    }

    $bounds = $selectedScreen.Bounds
    $physicalBounds = Get-PhysicalDisplayBounds -Screen $selectedScreen
    $previousDpiContext = [IntPtr]::Zero
    $usePhysicalBounds = $false

    if ($null -ne $physicalBounds) {
        try {
            Initialize-BootstrapNativeMethods
            $dpiAwarenessContextPerMonitorAwareV2 = [IntPtr](-4)
            $previousDpiContext = [PlayniteBootSwitchBootstrap.Native]::SetThreadDpiAwarenessContext(
                $dpiAwarenessContextPerMonitorAwareV2)
            $usePhysicalBounds = ($previousDpiContext -ne [IntPtr]::Zero)
        }
        catch {
            $previousDpiContext = [IntPtr]::Zero
            $usePhysicalBounds = $false
        }
    }

    try {
        if ($usePhysicalBounds) {
            $bounds = $physicalBounds
        }

        $form = New-Object System.Windows.Forms.Form
        $form.AutoScaleMode = [System.Windows.Forms.AutoScaleMode]::None
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
        $form.Bounds = $bounds
        $form.BackColor = [System.Drawing.Color]::Black
        $form.TopMost = $true
        $form.ShowInTaskbar = $false
        $form.ControlBox = $false

        $form.Show()
        $form.BringToFront()
        $form.Refresh()
        [System.Windows.Forms.Application]::DoEvents()
    }
    finally {
        if ($usePhysicalBounds -and $previousDpiContext -ne [IntPtr]::Zero) {
            try {
                [void][PlayniteBootSwitchBootstrap.Native]::SetThreadDpiAwarenessContext($previousDpiContext)
            }
            catch {
            }
        }
    }

    $readyEvent = [System.Threading.EventWaitHandle]::OpenExisting($SwitchReadyEventName)
    [void]$readyEvent.Set()

    # Keep the bootstrap form alive in this same PowerShell process while the
    # full runtime is parsed and initialized. PlayniteBoot.ps1 closes it only
    # after its normal black WPF overlay has rendered, so the handoff remains
    # black-to-black without a resident helper process.
    $global:PlayniteBootSwitchBootstrapForm = $form

    & $RuntimeScriptPath `
        -ConfigPath $ConfigPath `
        -Mode Switch `
        -SwitchStartUtcTicks $SwitchStartUtcTicks `
        -SwitchBootstrapActive
}
finally {
    if ($null -ne $readyEvent) {
        try { $readyEvent.Dispose() } catch {}
    }

    if ($null -ne $form -and -not $form.IsDisposed) {
        try { $form.Close() } catch {}
        try { $form.Dispose() } catch {}
    }

    $global:PlayniteBootSwitchBootstrapForm = $null
}
