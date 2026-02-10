param(
    [string]$Root = "."
)

$ErrorActionPreference = "Stop"
$projectRoot = (Resolve-Path -LiteralPath $Root).Path

if (-not (Test-Path -LiteralPath (Join-Path $projectRoot ".git"))) {
    throw "No .git directory found at: $projectRoot"
}

& git -C $projectRoot config --local core.hooksPath ".githooks"
if ($LASTEXITCODE -ne 0) {
    throw "Failed to configure core.hooksPath."
}

Write-Host "Git hooks installed. core.hooksPath=.githooks" -ForegroundColor Green
