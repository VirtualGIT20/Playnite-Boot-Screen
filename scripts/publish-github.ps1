param(
    [string]$Owner = 'VirtualGIT20',
    [string]$Repository = 'Playnite-Boot-Screen',
    [switch]$Private
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw 'Git was not found.'
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI was not found. Install it and run gh auth login.'
}

& gh auth status
if ($LASTEXITCODE -ne 0) {
    throw 'GitHub CLI is not authenticated. Run gh auth login.'
}

if (-not (Test-Path -LiteralPath (Join-Path $root '.git'))) {
    & git init -b main
}

& git add --all
$hasStagedChanges = $true
& git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    $hasStagedChanges = $false
}
if ($hasStagedChanges) {
    & git commit -m 'Publish repository state'
    if ($LASTEXITCODE -ne 0) {
        throw 'Git commit failed. Configure user.name and user.email, then retry.'
    }
}

$visibility = if ($Private) { '--private' } else { '--public' }
$remoteExists = (& git remote) -contains 'origin'
if (-not $remoteExists) {
    & gh repo create "$Owner/$Repository" $visibility --source . --remote origin --push
    if ($LASTEXITCODE -ne 0) {
        throw 'GitHub repository creation failed.'
    }
}
else {
    & git push -u origin main
    if ($LASTEXITCODE -ne 0) {
        throw 'Git push failed.'
    }
}

& gh repo edit "$Owner/$Repository" `
    --description "Custom Playnite Fullscreen boot video and Sunshine/Apollo streaming preload integration." `
    --add-topic playnite `
    --add-topic fullscreen `
    --add-topic boot-screen `
    --add-topic sunshine `
    --add-topic apollo `
    --add-topic powershell `
    --add-topic csharp
if ($LASTEXITCODE -ne 0) {
    Write-Warning 'Repository was published, but description or topics could not be updated automatically.'
}

Write-Host "Repository published: https://github.com/$Owner/$Repository"
