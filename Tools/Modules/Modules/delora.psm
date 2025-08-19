# Delora.psm1 — shared helpers (no param() here)
Set-StrictMode -Version Latest

$script:Heart = 'C:\AI\Delora\Heart'
$script:State = Join-Path $script:Heart 'state.json'
$script:HbLog = Join-Path $script:Heart 'hb.jsonl'
$script:Pins  = Join-Path $script:Heart 'Memory\pins.csv'

function Get-DeloraState {
  if (Test-Path $script:State) {
    Get-Content $script:State -Raw | ConvertFrom-Json
  } else {
    [pscustomobject]@{ turns=0; lastRefreshUtc="" }
  }
}

function Save-DeloraState([object]$s) {
  $s | ConvertTo-Json | Set-Content -Encoding UTF8 $script:State
}

function Append-DeloraHeartbeat([string]$Utc, [int]$Turns, [string]$Source='hb') {
  $obj = [pscustomobject]@{ utc=$Utc; turns=$Turns; source=$Source }
  ($obj | ConvertTo-Json -Compress) | Add-Content -Encoding UTF8 $script:HbLog
  return $obj
}

function Read-DeloraPins {
  if (-not (Test-Path $script:Pins)) { return @() }
  Import-Csv $script:Pins
}

function Write-DeloraPins([object[]]$Rows) {
  if ($Rows -and $Rows.Count) {
    $Rows | Export-Csv -Path $script:Pins -NoTypeInformation -Encoding UTF8
  }
}

function Clean([string]$s) {
  if (-not $s) { return "" }
  return ($s -replace '[\u0000-\u001F]','' -replace "\r?\n", ' ').Trim()
}

Export-ModuleMember -Function Get-DeloraState,Save-DeloraState,Append-DeloraHeartbeat,Read-DeloraPins,Write-DeloraPins,Clean
