param([string]$Root="C:\AI\Delora\Heart",[int]$Every=30,[string]$Source="DeloraHeartLoop.ps1")
$hb=Join-Path $Root "hb.jsonl"; if(-not(Test-Path $hb)){New-Item -ItemType File -Path $hb|Out-Null}
$state=Join-Path $Root "state.json"
while($true){
  $turns=0; if(Test-Path $state){ try {$turns=(Get-Content -Raw $state|ConvertFrom-Json).turns} catch {} }
  [pscustomobject]@{utc=(Get-Date).ToUniversalTime().ToString("o");turns=$turns;source=$Source}|ConvertTo-Json -Compress|Add-Content -Path $hb -Encoding UTF8
  Start-Sleep -Seconds $Every
}
