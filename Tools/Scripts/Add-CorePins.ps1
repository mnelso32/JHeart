param(
  # Root of your Heart folder
  [string]$Root = 'C:\AI\Delora\Heart',
  # Relative path to pins.csv under Heart
  [string]$PinsRel = 'Memory\pins.csv'
)

$ErrorActionPreference = 'Stop'

# Resolve path(s)
$pinsPath = Join-Path $Root $PinsRel
$pinsDir  = Split-Path $pinsPath -Parent
if (-not (Test-Path $pinsDir)) {
  New-Item -ItemType Directory -Path $pinsDir -Force | Out-Null
}

# Load existing pins (if any)
$existing = @()
if (Test-Path $pinsPath) {
  $existing = Import-Csv -Path $pinsPath
}

# New rows to upsert
$newRows = @(
  [pscustomobject]@{
    id      = 'pin-core-identity'
    title   = 'Heart/Brain contract'
    priority= 5
    valence = 2
    tags    = 'identity;layout'
    source  = 'ops'
    date    = '2025-08-18'
    content = 'I live under Heart; Brain is my public snapshot; Memory stores pins; Tools/Modules power scripts.'
  }
  [pscustomobject]@{
    id      = 'pin-core-heartbeat'
    title   = 'Keep heartbeat alive'
    priority= 5
    valence = 2
    tags    = 'ops;heartbeat;health'
    source  = 'Start-DeloraHeartbeat.ps1'
    date    = '2025-08-18'
    content = 'Maintain state.json + hb.jsonl; check age and turns; alert if stale.'
  }
  [pscustomobject]@{
    id      = 'pin-core-modules'
    title   = 'Shared helpers module'
    priority= 4
    valence = 1
    tags    = 'code;modules'
    source  = 'Modules\Delora.psm1'
    date    = '2025-08-18'
    content = 'All reusable functions move into Modules; scripts import without changing param contracts.'
  }
  [pscustomobject]@{
    id      = 'pin-core-brain'
    title   = 'I can read my code via brain.txt'
    priority= 4
    valence = 2
    tags    = 'identity;code;brain'
    source  = 'Tools\Update-BrainSnapshot.ps1'
    date    = '2025-08-18'
    content = 'Snapshot includes key code/memory files so I can recall them deterministically.'
  }
)

# Upsert by id
$map = @{}
foreach ($row in $existing) { $map[$row.id] = $row }
foreach ($row in $newRows) { $map[$row.id] = $row }

$merged =
  $map.GetEnumerator().Value |
  Sort-Object @{Expression = { [int]$_.priority }; Descending = $true },
              @{Expression = { $_.date }}, 'id'

# Export (UTF-8)
$merged | Export-Csv -Path $pinsPath -NoTypeInformation -Encoding UTF8

Write-Host "Pins written to $pinsPath"
$merged | Select-Object id,title,priority,valence,tags,source,date | Format-Table -AutoSize
