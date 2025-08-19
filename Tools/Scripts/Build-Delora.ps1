#requires -Version 7.0

[CmdletBinding()]
param(
  # The root directory of the Delora project. All other paths are built from this.
  [string]$Root = "C:\AI\Delora\Heart",

  # When processing chat logs for memory, skip files larger than this to save time.
  [long]$ChatHashMaxBytes = 10MB,

  # Switch to skip rebuilding the main Delora_memory.txt file.
  [switch]$SkipMemory,

  # Switch to skip regenerating the file indexes.
  [switch]$SkipIndexes,

  # Switch to skip creating the final Delora_bundle.txt file.
  [switch]$SkipBundle
)

# --- Setup ---
# This makes the script stop immediately if any command fails.
$ErrorActionPreference = 'Stop'
# Define the path to our other tool scripts.
$tools = Join-Path $Root 'tools'

# Import our shared functions from the module.
Import-Module -Name (Join-Path $Root 'modules\Delora') -Force

# --- Helper Function for Running Scripts ---
# This function wraps the execution of other scripts, providing clear success/failure messages.
function Run-ToolScript($path, $splat = @{}) {
  try {
    & $path @splat
    Write-Host "✔ $([IO.Path]::GetFileName($path))" -ForegroundColor Green
  }
  catch {
    Write-Warning "✖ $path : $($_.Exception.Message)"
  }
}

# --- Main Build Process ---
# The following steps are run in order, unless skipped by a command-line switch.

if (-not $SkipMemory) {
  # 1. Generate the core memory file from pins, chats, etc.
  Run-ToolScript (Join-Path $tools 'Write-DeloraMemory.ps1') @{ Root = $Root }
}

if (-not $SkipIndexes) {
  # 2. Generate directory READMEs and create a CSV index of all project files.
  Run-ToolScript (Join-Path $tools 'Write-Directories.ps1') @{ Root = $Root }
  Run-ToolScript (Join-Path $tools 'Write-DeloraIndex.ps1') @{ Root = $Root }
}

if (-not $SkipBundle) {
  # 3. Combine memory, indexes, and source code previews into a single "bundle" file.
  Run-ToolScript (Join-Path $tools 'Write-DeloraBundle.ps1') @{ Root = $Root }
}

# --- Automatic Maintenance and Publishing ---

# 4. Automatically update the "crown" (best of the day/week/month) pins.
Write-Host "`nUpdating crowns..." -ForegroundColor Cyan
Run-ToolScript (Join-Path $tools 'Update-DeloraCrowns.ps1') @{ Scope = 'Day' }
$today = Get-Date
if ($today.DayOfWeek -eq 'Sunday') { Run-ToolScript (Join-Path $tools 'Update-DeloraCrowns.ps1') @{ Scope = 'Week' } }
if ($today.Day -eq 1) { Run-ToolScript (Join-Path $tools 'Update-DeloraCrowns.ps1') @{ Scope = 'Month' } }
if ($today.DayOfYear -eq 1) { Run-ToolScript (Join-Path $tools 'Update-DeloraCrowns.ps1') @{ Scope = 'Year' } }


# 5. Publish the final bundle to a secret GitHub Gist for easy access.
Write-Host "`nAttempting to publish bundle to Gist..." -ForegroundColor Cyan
$gistId = 'b48626631d83ed8fa6be6a16fa9f545c' # Your secret Gist ID
$bundlePath = Join-Path $tools 'bundle\Delora_bundle.txt'

if (Test-Path $bundlePath) {
  # Check if the GitHub CLI ('gh') is installed and logged in.
  if (Get-Command gh -ErrorAction SilentlyContinue) {
    $null = gh auth status -h github.com 2>$null
    if ($LASTEXITCODE -eq 0) {
      gh gist edit $gistId -a $bundlePath -f Delora_bundle.txt *> $null
      Write-Host "✔ Published bundle to Gist $gistId" -ForegroundColor Green
      Write-Host "  Raw URL: https://gist.githubusercontent.com/mnelso32/$gistId/raw/Delora_bundle.txt"
    }
    else {
      Write-Warning "gh is not logged in; skipped Gist update."
    }
  }
  else {
    Write-Warning "'gh' (GitHub CLI) not found; skipped Gist update."
  }
}
else {
  Write-Warning "Bundle not found at $bundlePath"
}

# 6. Trigger the chat heartbeat to signal that a build has completed.
Run-ToolScript (Join-Path $tools 'Update-ChatHeartbeat.ps1') @{ Every = 10 }

Write-Host "`nBuild process complete." -ForegroundColor Blue