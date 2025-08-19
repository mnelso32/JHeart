param(
  [string]$RepoDir = 'C:\AI\Delora\Brain',         # a working clone
  [string]$Remote  = 'origin',
  [string]$Branch  = 'main'
)

# Build Brain\brain.txt and Brain\brain.csv from current files
# (safe on sizes; you can tune limits)

$heart = 'C:\AI\Delora\Heart'
$brain = Join-Path $heart 'Brain'
$txt   = Join-Path $brain 'brain.txt'
$csv   = Join-Path $brain 'brain.csv'

$paths = @(
  Join-Path $heart 'heart_memories.csv'
  Join-Path $heart 'Memory\pins.csv'
  Join-Path $heart 'Modules\Delora.psm1'
  Join-Path $heart 'Tools\Start-DeloraHeartbeat.ps1'
)

# CSV (index)
$rows = foreach ($p in $paths) {
  if (Test-Path $p) {
    $fi = Get-Item $p
    [pscustomobject]@{
      path   = $fi.FullName
      type   = $fi.Extension.TrimStart('.')
      mtime  = $fi.LastWriteTimeUtc.ToString('s')
      bytes  = $fi.Length
      tags   = if ($fi.Name -match 'pins') { 'memory;pins' } elseif ($fi.Name -match 'psm1|ps1'){ 'code' } else {'text'}
      note   = $fi.Name
    }
  }
}
$rows | Export-Csv -NoTypeInformation -Encoding UTF8 $csv

# TXT (human scan)
$content = @()
$content += "# Brain snapshot"
$content += "utc: $((Get-Date).ToUniversalTime().ToString('s'))"
$content += ""
foreach ($p in $paths) {
  if (Test-Path $p) {
    $content += "===== $p ====="
    $raw = Get-Content $p -Raw
    $content += ($raw.Length -gt 40000) ? ($raw.Substring(0,40000) + "`n[...truncated...]") : $raw
    $content += ""
  }
}
$content -join "`r`n" | Set-Content -Encoding UTF8 $txt

# --- Git Operations ---
$srcs  = @( (Join-Path $brain 'brain.txt'), (Join-Path $brain 'brain.csv') )

# ensure repo exists/cloned manually once; then:
Copy-Item $srcs -Destination $RepoDir -Force
Push-Location $RepoDir
git add brain.txt brain.csv *> $null
git commit -m "brain snapshot $(Get-Date -Format s)" *> $null
git push $Remote $Branch
Pop-Location