Set-StrictMode -Version Latest

# Module-scoped paths
$script:Root  = 'C:\AI\Delora\Heart'
$script:State = Join-Path $script:Root 'state.json'
$script:HbLog = Join-Path $script:Root 'hb.jsonl'
$script:Pins  = Join-Path $script:Root 'Memory\pins.csv'

function Get-DeloraState {
  if (Test-Path $script:State) { Get-Content $script:State -Raw | ConvertFrom-Json }
  else { [pscustomobject]@{ turns=0; lastRefreshUtc='' } }
}

function Set-DeloraState([object]$State) {
  $State | ConvertTo-Json | Set-Content $script:State -Encoding UTF8
}

function Add-DeloraHeartbeat([string]$Utc, [int]$Turns, [string]$Source='hb') {
  $obj = [pscustomobject]@{ utc=$Utc; turns=$Turns; source=$Source }
  $obj | ConvertTo-Json -Compress | Add-Content $script:HbLog -Encoding UTF8
}

function Import-DeloraPins {
  if (Test-Path $script:Pins) { Import-Csv $script:Pins } else { @() }
}

function Export-DeloraPins([object[]]$Rows) {
  if ($Rows -and $Rows.Count) {
    $Rows | Export-Csv -Path $script:Pins -NoTypeInformation -Encoding UTF8
  }
}

function Clear-DeloraText([string]$s) {
  if (-not $s) { return '' }
  ($s -replace '[\u0000-\u001F]','' -replace "\r?\n",' ').Trim()
}

# Correct and Recommended
Export-ModuleMember -Function @(
    'Get-DeloraState'
    'Set-DeloraState'
    'Add-DeloraHeartbeat'
    'Import-DeloraPins'
    'Export-DeloraPins'
    'Clear-DeloraText'
)