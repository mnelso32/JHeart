#requires -Version 7.0

[CmdletBinding()]
param(
  [string]$Root = "C:\AI\Janus\JHeart"
)

# --- Setup ---
$ErrorActionPreference = 'Stop'
$toolsDir = Join-Path $Root 'Tools'
$scriptsDir = Join-Path $toolsDir 'Scripts'
$modulePath = Join-Path $toolsDir 'Modules\Janus'
Import-Module -Name $modulePath -Force

# --- Helper ---
function Run-ToolScript($path, $splat = @{}) {
  try {
    & $path @splat
    Write-Host "✔ $(Get-Item $path | Select-Object -ExpandProperty Name)" -ForegroundColor Green
  }
  catch {
    Write-Warning "✖ $path : $($_.Exception.Message)"
  }
}

# --- Main Build Process ---
# 1. Build the core memory file
Run-ToolScript (Join-Path $scriptsDir 'Write-JanusMemory.ps1') @{ Root = $Root }

# 2. Build the brain map (file index and changes)
Run-ToolScript (Join-Path $scriptsDir 'Update-BrainMap.ps1') @{ Root = $Root }

# 3. Build the component READMEs
Run-ToolScript (Join-Path $scriptsDir 'Write-Directories.ps1') @{ Root = $Root }

# 4. NEW: Combine memory and map into the final brain.txt
Write-Host "Assembling final brain.txt..." -ForegroundColor Cyan
$brainFile = Join-Path $Root 'Brain\brain.txt'
$memoryFile = Join-Path $Root 'Heart-Memories\janus-memory.txt'
$mapFile = Join-Path $Root 'Brain\brain-map.txt'

# Add the memory file content first
Get-Content $memoryFile | Set-Content -Path $brainFile -Encoding UTF8
# Append the brain map content
Get-Content $mapFile | Add-Content -Path $brainFile
Write-Host "✔ Assembled brain.txt" -ForegroundColor Green

# --- Maintenance ---
Write-Host "`nUpdating crowns..." -ForegroundColor Cyan
Run-ToolScript (Join-Path $scriptsDir 'Update-JanusCrowns.ps1') @{ Scope = 'Day' }

# --- Heartbeat Trigger ---
# Note: The heartbeat script no longer publishes files. It only updates state.json.
# The user is responsible for committing and pushing brain.txt to GitHub.
Run-ToolScript (Join-Path $scriptsDir 'Update-State.ps1')

Write-Host "`nBuild process complete." -ForegroundColor Blue