param(
    [string]$Root = "."
)

$ErrorActionPreference = "Stop"

$gdFiles = Get-ChildItem -Path $Root -Recurse -Filter *.gd -File
$issues = @()

# Heuristic guard for accidental split keywords that break GDScript parsing.
$splitKeywordPatterns = @(
    '^\s*i\s+f\b',
    '^\s*e\s+l\s+i\s+f\b',
    '^\s*e\s+l\s+s\s+e\b',
    '^\s*f\s+o\s+r\b',
    '^\s*w\s+h\s+i\s+l\s+e\b',
    '^\s*m\s+a\s+t\s+c\s+h\b',
    '^\s*f\s+u\s+n\s+c\b',
    '^\s*r\s+e\s+t\s+u\s+r\s+n\b',
    '^\s*v\s+a\s+r\b',
    '^\s*c\s+o\s+n\s+s\s+t\b'
)

foreach ($file in $gdFiles) {
    $lineNo = 0
    Get-Content $file.FullName | ForEach-Object {
        $lineNo++
        $line = $_

        if ($line -match '^(<<<<<<<|=======|>>>>>>>)') {
            $issues += "MERGE MARKER: $($file.FullName):$lineNo"
        }

        foreach ($pattern in $splitKeywordPatterns) {
            if ($line -match $pattern) {
                $issues += "SPLIT KEYWORD: $($file.FullName):$lineNo -> $line"
                break
            }
        }
    }
}

if ($issues.Count -gt 0) {
    Write-Host "GDScript sanity check failed:" -ForegroundColor Red
    $issues | ForEach-Object { Write-Host " - $_" }
    exit 1
}

Write-Host "GDScript sanity check passed for $($gdFiles.Count) files." -ForegroundColor Green
exit 0
