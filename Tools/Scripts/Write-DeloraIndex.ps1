#requires -Version 7.0

param([switch]$HashTextOnly)

$ErrorActionPreference = 'Stop'
$PSDefaultParameterValues['Export-Csv:Encoding'] = 'utf8'
$PSDefaultParameterValues['Out-File:Encoding']   = 'utf8'

$root     = "C:\AI\Delora"
$outDir   = Join-Path $root "tools\indexes"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$idxCsv     = Join-Path $outDir 'Delora_listing.csv'
$prevCsv    = Join-Path $outDir 'Delora_listing_prev.csv'
$changesTxt = Join-Path $outDir 'Delora_changes.txt'

# keep a previous snapshot (if any)
if (Test-Path $idxCsv) { Copy-Item -LiteralPath $idxCsv -Destination $prevCsv -Force }

# Extensions you care about (no leading dots here)
$exts = 'ps1','psm1','psd1','txt','md','json','js','ts','tsx','css','yml','yaml','ini','csv'

$rows = Get-ChildItem $root -Recurse -File -ErrorAction SilentlyContinue |
  ForEach-Object {
    $type = ([string]$_.Extension).ToLowerInvariant().TrimStart('.')
    if ($type -in $exts) {
      [pscustomobject]@{
        Path         = $_.FullName
        Type         = $type
        SizeBytes    = [int64]$_.Length
        LastWriteUtc = $_.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mm:ss')
        When         = $_.LastWriteTimeUtc.ToUniversalTime()   # handy for RECENT
        SHA256       = ''                                      # fast mode
      }
    }
  } | Where-Object { $_ }   # keep only emitted objects


$rows | Sort-Object Path | Export-Csv -Path $idxCsv -NoTypeInformation -Encoding UTF8
Write-Host "Wrote index: $idxCsv"

# --- compute CHANGES (add/remove) ---
$lines = @()
if (Test-Path $prevCsv) {
  $prev = Import-Csv $prevCsv
  $curr = Import-Csv $idxCsv

  $prev = if (Test-Path $prevCsv) { Import-Csv $prevCsv } else { @() }
$curr = if (Test-Path $idxCsv)  { Import-Csv $idxCsv  } else { @() }

# Extract just the paths; coerce to arrays and drop null/empty entries
$prevPaths = @($prev | ForEach-Object { $_.Path }) | Where-Object { $_ }
$currPaths = @($curr | ForEach-Object { $_.Path }) | Where-Object { $_ }

$removed = Compare-Object `
  -ReferenceObject  $prevPaths `
  -DifferenceObject $currPaths `
  -PassThru |
  Where-Object SideIndicator -eq '<='

$added   = Compare-Object `
  -ReferenceObject  $prevPaths `
  -DifferenceObject $currPaths `
  -PassThru |
  Where-Object SideIndicator -eq '=>'


  $lines += 'REMOVED:'
  # If you only care about text files here, uncomment the filter:
  # $removed = $removed | Where-Object { $_ -like '*.txt' }
  $lines += ($removed | Sort-Object)
  $lines += ''
  $lines += 'ADDED:'
  # $added = $added | Where-Object { $_ -like '*.txt' }
  $lines += ($added   | Sort-Object)
}

# --- RECENT previews (write tools\indexes\Delora_recent.txt) ---
$recentMax        = 12          # how many files to show
$maxPreviewLines  = 120         # lines per file
$maxPreviewBytes  = 256KB       # skip very large files
$previewExts      = 'ps1','psm1','psd1','txt','md','json','csv','cfg','yml','yaml','js','ts','tsx','css'

# pick most recent rows (we added When above)
$recentRows = $rows |
  Sort-Object When -Descending |
  Select-Object -First $recentMax

$recentTxt = Join-Path $outDir 'Delora_recent.txt'
$sb = New-Object System.Text.StringBuilder

foreach ($r in $recentRows) {
  $full = $r.Path
  $rel  = $full.Replace($root,'').TrimStart('\')

  [void]$sb.AppendLine("== $rel")

  if ($r.SizeBytes -le $maxPreviewBytes -and ($previewExts -contains $r.Type)) {
    try {
      $head = Get-Content -LiteralPath $full -TotalCount $maxPreviewLines -Encoding UTF8 -ErrorAction Stop
    } catch { $head = @('<unreadable or locked>') }
    [void]$sb.AppendLine(($head -join "`n"))
  } else {
    [void]$sb.AppendLine('<binary or too large>')
  }

  [void]$sb.AppendLine('')
}

Set-Content -Path $recentTxt -Value ($sb.ToString()) -Encoding UTF8
Write-Host "Wrote recent: $recentTxt"
# --- end RECENT previews ---





