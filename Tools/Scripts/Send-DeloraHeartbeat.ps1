param([string]$Root="C:\AI\Delora\Heart",[string]$Source="Send-DeloraHeartbeat.ps1")
$hb = Join-Path $Root "hb.jsonl"
if (-not (Test-Path $hb)) { New-Item -ItemType File -Path $hb | Out-Null }
$turns = 0
$state = Join-Path $Root "state.json"
if (Test-Path $state) { try { $turns = (Get-Content -Raw $state | ConvertFrom-Json).turns } catch {} }
[pscustomobject]@{ utc=(Get-Date).ToUniversalTime().ToString("o"); turns=$turns; source=$Source } | ConvertTo-Json -Compress | Add-Content -Path $hb -Encoding UTF8
