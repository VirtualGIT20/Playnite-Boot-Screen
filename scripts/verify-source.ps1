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

Write-Host 'Checking runtime and media files...'
$runtimeVersionPath = Join-Path $root 'PlayniteBoot\RuntimeTemplate\VERSION.txt'
$runtimeVersion = (Get-Content -LiteralPath $runtimeVersionPath -Raw).Trim()
if ($runtimeVersion -notmatch '^\d+\.\d+\.\d+$') {
    throw "Invalid runtime version: $runtimeVersion"
}

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
