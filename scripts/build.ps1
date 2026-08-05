param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$solution = Join-Path $root 'PlayniteBoot.sln'
$projectDirectory = Join-Path $root 'PlayniteBoot'
$output = Join-Path $projectDirectory "bin\$Configuration"
$intermediate = Join-Path $projectDirectory "obj\$Configuration"

function Find-MSBuild {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
    if (Test-Path -LiteralPath $vswhere) {
        $result = & $vswhere -latest -products * -requires Microsoft.Component.MSBuild -find MSBuild\**\Bin\MSBuild.exe |
            Select-Object -First 1
        if ($result) {
            return $result
        }
    }

    $candidate = Get-Command msbuild.exe -ErrorAction SilentlyContinue
    if ($candidate) {
        return $candidate.Source
    }

    return $null
}

$msbuild = Find-MSBuild
if (-not $msbuild) {
    throw 'MSBuild was not found. Install Visual Studio or Visual Studio Build Tools with .NET desktop build tools.'
}

$frameworkList = Join-Path ${env:ProgramFiles(x86)} 'Reference Assemblies\Microsoft\Framework\.NETFramework\v4.6.2\RedistList\FrameworkList.xml'
if (-not (Test-Path -LiteralPath $frameworkList)) {
    throw '.NET Framework 4.6.2 Targeting Pack was not found. Install the 4.6.2 SDK and Targeting Pack from Visual Studio Installer.'
}

foreach ($directory in @($output, $intermediate)) {
    if (Test-Path -LiteralPath $directory) {
        Remove-Item -LiteralPath $directory -Recurse -Force
    }
}

Write-Host "MSBuild: $msbuild"
Write-Host 'Restoring NuGet packages (packages.config)...'
& $msbuild $solution /t:Restore /m /p:RestorePackagesConfig=true /p:Configuration=$Configuration /p:Platform='Any CPU'
if ($LASTEXITCODE -ne 0) {
    throw "NuGet restore failed with exit code $LASTEXITCODE."
}

Write-Host "Building clean $Configuration output..."
& $msbuild $solution /t:Build /m /p:Configuration=$Configuration /p:Platform='Any CPU'
if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE."
}

if (-not (Test-Path -LiteralPath (Join-Path $output 'PlayniteBoot.dll') -PathType Leaf)) {
    throw "Build completed without producing PlayniteBoot.dll in $output."
}

Write-Host "Build completed: $output"
