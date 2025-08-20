#requires -Version 7.0

[CmdletBinding()]
param(
  [string]$Root = "C:\AI\Janus\JHeart",
  [switch]$SkipMemory,
  [switch]$SkipIndexes,
  [switch]$SkipBrain
)

# --- Setup ---
$ErrorActionPreference = 'Stop'
$toolsDir = Join-Path $Root 'Tools'
$scriptsDir = Join-Path $toolsDir 'Scripts'
$modulePath = Join-Path $toolsDir 'Modules\Janus.psm1'
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
if (-not $SkipMemory) {
  Run-ToolScript (Join-Path $scriptsDir 'Write-JanusMemory.ps1') @{ Root = $Root }
}

if (-not $SkipIndexes) {
  Run-ToolScript (Join-Path $scriptsDir 'Update-BrainMap.ps1') @{ Root = $Root }
}

if (-not $SkipBrain) {
  Write-Host "Assembling final brain.txt..." -ForegroundColor Cyan
  $brainFile = Join-Path $Root 'Brain\brain.txt'
  $memoryFile = Join-Path $Root 'Heart-Memories\janus-memory.txt'
  $mapFile = Join-Path $Root 'Brain\brain-map.txt'

  # Add the memory file content first
  Get-Content $memoryFile | Set-Content -Path $brainFile -Encoding UTF8
  # Append the brain map content
  Get-Content $mapFile | Add-Content -Path $brainFile
  Write-Host "✔ Assembled brain.txt" -ForegroundColor Green
}

# --- Maintenance ---
Write-Host "`nUpdating crowns..." -ForegroundColor Cyan
Run-ToolScript (Join-Path $scriptsDir 'Update-JanusCrowns.ps1') @{ Scope = 'Day' }

# --- Heartbeat Trigger ---
Run-ToolScript (Join-Path $scriptsDir 'Update-State.ps1')

Write-Host "`nBuild process complete." -ForegroundColor Blue