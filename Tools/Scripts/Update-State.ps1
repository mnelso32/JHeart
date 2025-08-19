#requires -Version 7.0
#
# This script's job is to update the local state file to track "turns"
# and the time of the last update.

[CmdletBinding()]
param(
    [string]$Root = "C:\AI\Janus\JHeart"
)

# --- Setup ---
$ErrorActionPreference = "SilentlyContinue"
$statePath = Join-Path $Root 'state.json'

# --- Helper Functions ---
function Read-State {
    param([string]$Path)
    if (Test-Path $Path) {
        # Use -Raw to read the entire file at once, which is faster for small JSON files
        return Get-Content $Path -Raw | ConvertFrom-Json
    }
    # Return a default object if the file doesn't exist
    return [pscustomobject]@{ turns = 0; lastRefreshUtc = "" }
}

function Write-State {
    param([string]$Path, [object]$State)
    $dir = Split-Path $Path
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    # ConvertTo-Json with a depth of 3 is usually sufficient and safe
    $State | ConvertTo-Json -Depth 3 | Set-Content -Path $Path -Encoding UTF8
}

# --- Main Logic ---
$state = Read-State $statePath
$state.turns = [int]$state.turns + 1
# Use the standard 'o' format specifier for a round-trippable ISO 8601 timestamp
$state.lastRefreshUtc = (Get-Date).ToUniversalTime().ToString('o')

Write-State -Path $statePath -State $state

Write-Host "✔ Heartbeat state updated. Turns: $($state.turns)" -ForegroundColor Green

