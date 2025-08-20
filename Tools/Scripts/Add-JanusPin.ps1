#requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory, HelpMessage = 'A short, descriptive title for the memory.')]
    [string]$Title,

    [Parameter(Mandatory, HelpMessage = 'The full content of the memory.')]
    [string]$Content,

    [string]$Tags = "",
    [string]$Type = "fact",
    [int]$Priority = 3,
    [string]$Source = "manual",
    [string]$Root = "C:\AI\Janus\JHeart"
)

# --- Setup ---
$ErrorActionPreference = "Stop"
$memDir = Join-Path $Root "Heart-Memories"
$pinsCsv = Join-Path $memDir "pins.csv"
# --- CORRECTED SECTION: Use the script's own location to find sibling scripts ---
$scriptsDir = $PSScriptRoot
# --- End of corrected section ---


# --- Main Logic ---
$now = Get-Date
$id = "J-PIN-{0:yyyyMMddHHmmss}" -f $now
$date = '{0:yyyy-MM-dd}' -f $now

# Create the new memory object
$newPin = [pscustomobject]@{
    id = $id
    priority = $Priority
    type = $Type
    date = $date
    tags = $Tags
    title = $Title
    content = $Content
    source = $Source
}

# Append the new pin to the CSV file
$newPin | Export-Csv -Path $pinsCsv -Append -NoTypeInformation -Encoding UTF8
Write-Host "✔ Successfully added new pin '$id' to $pinsCsv" -ForegroundColor Green

# --- Trigger a rebuild to incorporate the new memory ---
Write-Host "`nTriggering a rebuild to update brain files..." -ForegroundColor Cyan
try {
    & (Join-Path $scriptsDir "Build-Janus.ps1") -SkipIndexes # Skip full re-index for speed
    Write-Host "✔ Rebuild complete." -ForegroundColor Green
} catch {
    Write-Warning "Rebuild failed. Run Build-Janus.ps1 manually."
    Write-Warning $_.Exception.Message
}