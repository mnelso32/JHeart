<#
.SYNOPSIS
  Keeps the Delora memory bundle fresh and drops a fast "beacon" (hb.txt) so the assistant can
  detect updates instantly on the next chat turn.

.DESCRIPTION
  - Tracks a tiny state file (turn counter + last refresh UTC).
  - Every N "turns" (or when forced / time window elapsed) it:
      * (optionally) rebuilds the bundle
      * publishes the bundle.txt to your secret Gist
      * writes/updates hb.txt beacon in the same Gist
      * updates state.json with new lastRefreshUtc and turn count

.PARAMETER Every
  Publish cadence in "turns" (script runs). If 0, disables turn-based cadence.

.PARAMETER MinMinutes
  Also publish when at least this many minutes have elapsed since the last refresh (0 disables).

.PARAMETER Rebuild
  If set, runs Build-Delora.ps1 before publishing.

.PARAMETER Force
  If set, publish now regardless of cadence/time checks.

.PARAMETER GistId
  Your secret Gist id that holds the bundle and hb.txt.

.PARAMETER Root
  Root folder for the Delora project (default C:\AI\Delora).

.PARAMETER StatePath
  Path to the state.json file (default <Root>\memory\state.json).

.PARAMETER BundlePath
  Path to the bundle file (default <Root>\tools\bundle\Delora_bundle.txt).

.EXAMPLE
  pwsh -File C:\AI\Delora\tools\Update-ChatHeartbeat.ps1 -Every 10 -MinMinutes 15 -GistId 'b4862...f545c' -Rebuild

.NOTES
  - Designed to run silently under Windows Task Scheduler every 10 minutes.
  - Uses GitHub CLI `gh gist edit` to update files in-place without changing the Gist id.
#>

[CmdletBinding()]
param(
  [int]$Every        = 10,
  [int]$MinMinutes   = 0,
  [switch]$Rebuild,
  [switch]$Force,
  [Parameter(Mandatory=$true)][string]$GistId,
  [string]$Root      = 'C:\AI\Delora\Heart',
  [string]$StatePath = $null,
  [string]$BundlePath= $null
)

# ---- Resolve paths -----------------------------------------------------------
if (-not $StatePath)  { $StatePath  = Join-Path $Root 'memory\state.json' }
if (-not $BundlePath) { $BundlePath = Join-Path $Root 'tools\bundle\Delora_bundle.txt' }
$Tools = Join-Path $Root 'tools'

# ---- Helpers ----------------------------------------------------------------
function Read-State {
  param([string]$Path)
  if (Test-Path $Path) {
    try   { Get-Content $Path -Raw | ConvertFrom-Json }
    catch { [pscustomobject]@{ turns = 0; lastRefreshUtc = "" } }
  } else {
    [pscustomobject]@{ turns = 0; lastRefreshUtc = "" }
  }
}

function Write-State {
  param([string]$Path,[object]$State)
  $dir = Split-Path $Path
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $State | ConvertTo-Json | Set-Content -Path $Path -Encoding UTF8
}

function Publish-FileToGist {
  param(
    [Parameter(Mandatory)][string]$GistId,
    [Parameter(Mandatory)][string]$LocalPath,
    [Parameter(Mandatory)][string]$GistFileName
  )
  if (-not (Test-Path $LocalPath)) {
    Write-Warning "Publish-FileToGist: missing local file: $LocalPath"
    return $false
  }
  # `-a` attaches/updates the file; `-f` sets its name inside the gist
  $null = & gh gist edit $GistId -a $LocalPath -f $GistFileName 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Warning "Publish-FileToGist: gh returned code $LASTEXITCODE for $GistFileName"
    return $false
  }
  return $true
}

function New-BeaconFile {
  param([datetime]$Utc,[int]$Turns)
  $tmp = New-TemporaryFile
  # Simple, easy-to-parse content
  @(
    "utc: $($Utc.ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    "turns: $Turns"
  ) | Set-Content $tmp -Encoding UTF8
  return $tmp
}

# ---- Load + bump state -------------------------------------------------------
$state = Read-State $StatePath
$state.turns = [int]$state.turns + 1

$nowUtc   = (Get-Date).ToUniversalTime()
[datetime]$lastUtc = [datetime]::MinValue
$ageMin   = $null
$hasLast  = [datetime]::TryParse([string]$state.lastRefreshUtc, [ref]$lastUtc)
if ($hasLast) { $ageMin = [math]::Round(($nowUtc - $lastUtc).TotalMinutes, 1) } else { $ageMin = [double]::PositiveInfinity }

# ---- Decide if we should publish --------------------------------------------
$byTurns   = ($Every -gt 0) -and ($state.turns % $Every -eq 0)
$byMinutes = ($MinMinutes -gt 0) -and ($ageMin -ge $MinMinutes) -and $hasLast
$firstTime = -not $hasLast
$should    = $Force -or $firstTime -or $byTurns -or $byMinutes

Write-Verbose ("Turns={0} | LastRefreshUtc={1} | AgeMin={2} | Publish? {3}" -f $state.turns, ($state.lastRefreshUtc ?? "<none>"), $ageMin, $should)

# ---- Optional rebuild (fast) ------------------------------------------------
if ($should -and $Rebuild) {
  $build = Join-Path $Tools 'Build-Delora.ps1'
  if (Test-Path $build) {
    # You can add -SkipIndexes if you want a lighter rebuild
    $null = & $build *> $null
  } else {
    Write-Warning "Rebuild requested but not found: $build"
  }
}

# ---- Publish bundle + beacon -------------------------------------------------
if ($should) {
  $bundleOK = Publish-FileToGist -GistId $GistId -LocalPath $BundlePath -GistFileName 'Delora_bundle.txt'
  # Beacon: tiny freshness indicator
  $hb = New-BeaconFile -Utc $nowUtc -Turns $state.turns
  $beaconOK = Publish-FileToGist -GistId $GistId -LocalPath $hb -GistFileName 'hb.txt'
  Remove-Item $hb -ErrorAction SilentlyContinue

  if ($bundleOK -and $beaconOK) {
    $state.lastRefreshUtc = $nowUtc.ToString('o')  # ISO 8601 with Z offset
  } else {
    Write-Warning "Publish step incomplete (bundleOK=$bundleOK, beaconOK=$beaconOK)"
  }
}

# ---- Save state and exit silently -------------------------------------------
Write-State -Path $StatePath -State $state


