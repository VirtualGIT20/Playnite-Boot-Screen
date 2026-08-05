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
if ($version -notmatch '^\d+\.\d+\.\d+$') {
    throw "Invalid extension version in extension.yaml: $version"
}

$output = Join-Path $root "PlayniteBoot\bin\$Configuration"
$allowedTopLevelFiles = @('PlayniteBoot.dll', 'extension.yaml', 'icon.png')
$allowedTopLevelDirectories = @('Localization', 'RuntimeTemplate')
$outputRoot = [IO.Path]::GetFullPath($output)
$outputRoot = $outputRoot.TrimEnd([char[]]@([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)) + [IO.Path]::DirectorySeparatorChar

$unexpectedFiles = @(
    Get-ChildItem -LiteralPath $output -File -Recurse | Where-Object {
        $relativePath = $_.FullName.Substring($outputRoot.Length)
        $parts = $relativePath -split '[\\/]'
        if ($parts.Count -eq 1) {
            $allowedTopLevelFiles -notcontains $parts[0]
        }
        else {
            $allowedTopLevelDirectories -notcontains $parts[0]
        }
    }
)

if ($unexpectedFiles.Count -gt 0) {
    $relativeFiles = $unexpectedFiles | ForEach-Object { $_.FullName.Substring($outputRoot.Length) }
    throw "Unexpected files were found in the extension build output:`n$($relativeFiles -join "`n")"
}

$requiredFiles = @(
    'PlayniteBoot.dll',
    'extension.yaml',
    'icon.png',
    'Localization\en_US.xaml',
    'Localization\it_IT.xaml',
    'RuntimeTemplate\PlayniteBoot.ps1',
    'RuntimeTemplate\Launch-PlayniteBoot.vbs',
    'RuntimeTemplate\Install-Shortcut.ps1',
    'RuntimeTemplate\Test-Configuration.ps1',
    'RuntimeTemplate\VERSION.txt',
    'RuntimeTemplate\media\boot-4k60.mp4'
)

$missingFiles = @($requiredFiles | Where-Object { -not (Test-Path -LiteralPath (Join-Path $output $_) -PathType Leaf) })
if ($missingFiles.Count -gt 0) {
    throw "Required files are missing from the extension build output:`n$($missingFiles -join "`n")"
}

$Destination = [IO.Path]::GetFullPath($Destination)
New-Item -Path $Destination -ItemType Directory -Force | Out-Null
$temporaryDestination = Join-Path ([IO.Path]::GetTempPath()) ("PlayniteBoot-pack-" + [Guid]::NewGuid().ToString('N'))
New-Item -Path $temporaryDestination -ItemType Directory -Force | Out-Null
$targetPath = $null
$hashPath = $null

try {
    & $ToolboxPath pack $output $temporaryDestination
    if ($LASTEXITCODE -ne 0) {
        throw "Packaging failed with exit code $LASTEXITCODE."
    }

    $packages = @(Get-ChildItem -LiteralPath $temporaryDestination -Filter '*.pext' -File -Recurse)
    if ($packages.Count -ne 1) {
        throw "Toolbox must produce exactly one .pext package; found $($packages.Count)."
    }

    $targetPath = Join-Path $Destination "Playnite-Boot-Screen-v$version.pext"
    $hashPath = $targetPath + '.sha256'

    foreach ($existingFile in @($targetPath, $hashPath)) {
        if (Test-Path -LiteralPath $existingFile) {
            Remove-Item -LiteralPath $existingFile -Force
        }
    }

    Move-Item -LiteralPath $packages[0].FullName -Destination $targetPath

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $archive = [IO.Compression.ZipFile]::OpenRead($targetPath)
    try {
        $packageEntries = @(
            $archive.Entries |
                Where-Object { -not [string]::IsNullOrEmpty($_.Name) } |
                ForEach-Object { $_.FullName.Replace('/', '\') }
        )

        $unexpectedPackageEntries = @(
            $packageEntries | Where-Object {
                $parts = $_ -split '[\\/]'
                if ($parts.Count -eq 1) {
                    $allowedTopLevelFiles -notcontains $parts[0]
                }
                else {
                    $allowedTopLevelDirectories -notcontains $parts[0]
                }
            }
        )
        if ($unexpectedPackageEntries.Count -gt 0) {
            throw "Unexpected files were found in the .pext package:`n$($unexpectedPackageEntries -join "`n")"
        }

        $missingPackageEntries = @($requiredFiles | Where-Object { $packageEntries -notcontains $_ })
        if ($missingPackageEntries.Count -gt 0) {
            throw "Required files are missing from the .pext package:`n$($missingPackageEntries -join "`n")"
        }
    }
    finally {
        $archive.Dispose()
    }

    $hash = Get-FileHash -LiteralPath $targetPath -Algorithm SHA256
    "$($hash.Hash.ToLowerInvariant())  $([IO.Path]::GetFileName($targetPath))" |
        Set-Content -LiteralPath $hashPath -Encoding ASCII

    Write-Host "Package: $targetPath"
    Write-Host "SHA-256: $hashPath"
}
catch {
    foreach ($failedFile in @($targetPath, $hashPath)) {
        if ($failedFile -and (Test-Path -LiteralPath $failedFile)) {
            Remove-Item -LiteralPath $failedFile -Force -ErrorAction SilentlyContinue
        }
    }
    throw
}
finally {
    if (Test-Path -LiteralPath $temporaryDestination) {
        Remove-Item -LiteralPath $temporaryDestination -Recurse -Force
    }
}
