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
    $form = New-Object System.Windows.Forms.Form
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
