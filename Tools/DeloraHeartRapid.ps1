param([string]$Root="C:\AI\Delora\Heart",[int]$EveryMs=1500)
$ErrorActionPreference = "Stop"

$hb     = Join-Path $Root "hb.jsonl"
$state  = Join-Path $Root "state.json"
$source = "DeloraHeartRapid.ps1"

$created = $false
$m = New-Object System.Threading.Mutex($false,"Global\DeloraHeartRapid",[ref]$created)
if(-not $created){ return }
try {
  if(-not (Test-Path $hb)) { New-Item -ItemType File -Path $hb | Out-Null }
  function Write-Beat {
    $turns = 0
    try { if (Test-Path $state) { $turns = (Get-Content -Raw $state | ConvertFrom-Json).turns } } catch {}
    $obj = [ordered]@{ utc=(Get-Date).ToUniversalTime().ToString("o"); turns=$turns; source=$source }
    $line = ($obj | ConvertTo-Json -Compress)
    Add-Content -Path $hb -Value $line -Encoding UTF8
  }
  while($true){
    Write-Beat
    Start-Sleep -Milliseconds $EveryMs
  }
} finally {
  if($m){ $m.ReleaseMutex() | Out-Null; $m.Dispose() }
}
