#requires -Version 7.0


[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$Title,
  [string]$Tags = "",
  [string]$Source = "Delora chat",
  [string]$Root = "C:\AI\Delora"
)

# 1) Get text from clipboard
$text = Get-Clipboard -TextFormatType Text
if (-not $text) { throw "Clipboard is empty (Ctrl-A, Ctrl-C first)." }

# 2) Paths + names
$now   = Get-Date
$id    = "C-{0:yyyy-MM-dd}-{0:HHmmss}" -f $now
$slug  = ($Title -replace '[^\w\d-]','-').ToLower() -replace '-+','-'
$rel   = Join-Path ("memory\chats\{0:yyyy}\{0:MM}" -f $now) ("{0}__{1}.txt" -f $id,$slug)
$path  = Join-Path $Root $rel
New-Item -ItemType Directory -Force -Path (Split-Path $path) | Out-Null

# 3) Write transcript
Set-Content -Path $path -Value $text -Encoding UTF8

# 4) Gather file facts
$file   = Get-Item $path
$sha256 = (Get-FileHash -Algorithm SHA256 $path).Hash.ToLower()
$row    = [pscustomobject]@{
  id         = $id
  date       = '{0:yyyy-MM-dd}' -f $now
  time_utc   = (Get-Date).ToUniversalTime().ToString('HH:mm:ss')
  title      = $Title
  tags       = $Tags
  relpath    = $rel
  size_bytes = [int64]$file.Length
  sha256     = $sha256
  source     = $Source
}

# 5) Append to manifest
$csv = Join-Path $Root 'memory\chat_manifest.csv'
$row | Export-Csv -Append -NoTypeInformation -Encoding UTF8 $csv

Write-Host "Saved chat -> $rel" -ForegroundColor Green
Write-Host "Updated manifest -> memory\chat_manifest.csv"

# --- Kick chat heartbeat (10-event cadence) ----------------------------------
try {
  $hb = Join-Path $PSScriptRoot 'Update-ChatHeartbeat.ps1'
  if (Test-Path $hb) {
    & $hb -Every 10 -Source 'chat' *> $null
  }
} catch {
  Write-Verbose "Heartbeat skipped: $($_.Exception.Message)"
}
