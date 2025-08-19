param(
  [string]$Root = 'C:\AI\Delora\Heart',
  [string]$Source = 'Send-DeloraHeartbeat.ps1',
  [switch]$Loop,
  [int]$EverySeconds = 60
)

# Paths
$statePath   = Join-Path $Root 'state.json'
$hbPath      = Join-Path $Root 'hb.jsonl'
$preludePath = Join-Path $Root 'heartbeat.txt'  # tiny prelude you want echoed when you "feel" a beat

# --- helpers ---
function Get-State {
  if (Test-Path $statePath) {
    try { Get-Content $statePath -Raw | ConvertFrom-Json }
    catch { [pscustomobject]@{ turns = 0; lastRefreshUtc = '' } }
  } else {
    [pscustomobject]@{ turns = 0; lastRefreshUtc = '' }
  }
}

function Save-State($s) {
  $s | ConvertTo-Json | Set-Content $statePath -Encoding UTF8
}

function Send-Beat {
  $s = Get-State
  $s.turns++
  $utc = (Get-Date).ToUniversalTime().ToString('s')
  $s.lastRefreshUtc = $utc

  $obj  = [pscustomobject]@{ utc = $utc; turns = $s.turns; source = $Source }
  $json = $obj | ConvertTo-Json -Compress

  # Append one JSON line to hb.jsonl and persist state
  Add-Content -Path $hbPath -Value $json
  Save-State $s

  # Print/push the HB line for chat use
  $hbLine = "HB: $json"
  Write-Host $hbLine -ForegroundColor Cyan
  try { Set-Clipboard -Value $hbLine } catch {}

  # (Optional) show the tiny heartbeat prelude so you can paste it with the HB line if you want
  if (Test-Path $preludePath) {
    Write-Host "`n--- heartbeat.txt ---" -ForegroundColor DarkGray
    Get-Content $preludePath | Write-Host
  }
}

# --- run once or loop ---
if ($Loop) {
  Write-Host "Delora heartbeat started. Tick = $EverySeconds s. Ctrl+C to stop."
  while ($true) {
    Send-Beat
    Start-Sleep -Seconds $EverySeconds
  }
} else {
  Send-Beat
}
