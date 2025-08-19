#requires -Version 7.0

param(
  # The root directory of the Delora project.
  [string]$Root = "C:\AI\Delora\Heart",
  # The output directory for the bundle and its manifest.
  [string]$OutDir = "C:\AI\Delora\Heart\tools\bundle",
  # For file previews, how many lines to take from the start.
  [int]$HeadLines = 120,
  # For file previews, how many lines to take from the end.
  [int]$TailLines = 60,
  # A safety limit to prevent any one section from being enormous.
  [int]$MaxCharsPerSection = 40000
)

$ErrorActionPreference = 'Stop'
# --- Setup ---
$bundlePath = Join-Path $OutDir 'Delora_bundle.txt'
$manifestPath = Join-Path $OutDir 'Delora_manifest.csv'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
if (Test-Path $bundlePath) { Remove-Item $bundlePath -Force }
if (Test-Path $manifestPath) { Remove-Item $manifestPath -Force }

# Import our shared functions from the module.
Import-Module -Name (Join-Path $Root 'modules\Delora') -Force


# --- Local Helper Functions (specific to this script) ---

# This function formats and appends a new section to the bundle and a corresponding row to the manifest.
function Add-BundleSection([string]$id, [string]$path, [string]$body) {
  $relPath = Get-DeloraRelativePath -Path $path -Root $Root
  $fileInfo = Get-Item $path -ErrorAction SilentlyContinue
  $size = if ($fileInfo) { $fileInfo.Length } else { 0 }
  $mtime = if ($fileInfo) { $fileInfo.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mm:ss') } else { '' }
  $sha = if ($fileInfo) { Get-DeloraFileHash -Path $path } else { '' }

  $header = @"
================================================================================
== $id :: $relPath
== size=$size  mtime(Utc)=$mtime  sha256=$sha
================================================================================
"@
  Add-Content -Path $bundlePath -Value $header
  # Truncate the body if it exceeds the max character limit
  if ($body.Length -gt $MaxCharsPerSection) {
    $body = $body.Substring(0, $MaxCharsPerSection) + "`n[... TRUNCATED ...]"
  }
  Add-Content -Path $bundlePath -Value $body
  Add-Content -Path $bundlePath -Value "`n`n"

  # Add a metadata entry to the manifest CSV file
  [pscustomobject]@{
    SectionId = $id
    RelPath = $relPath
    SizeBytes = $size
    LastWriteUtc = $mtime
    SHA256 = $sha
  } | Export-Csv -Path $manifestPath -Append -NoTypeInformation -Encoding UTF8
}

# --- Main Logic ---

# We'll build a Table of Contents (TOC) as we go, then prepend it at the end.
$TOC = @()
function Add-TOCEntry([string]$id, [string]$description) { $script:TOC += ("- {0} :: {1}" -f $id, $description) }

# SECTION 1: MEMORY
# Start with the most important data: the global memory file.
$memFile = Join-Path $Root 'memory\heart-memories.txt'
if (Test-Path $memFile) {
  $memBody = Get-Content -Path $memFile -Raw -Encoding UTF8
  Add-TOCEntry 'MEMORY' (Get-DeloraRelativePath -Path $memFile -Root $Root)
  Add-BundleSection 'MEMORY' $memFile $memBody
}

# SECTION 2: INDEXES
# Include summaries of all files in the project and recent changes.
$idxCsv = Join-Path $Root 'tools\indexes\Delora_listing.csv'
if (Test-Path $idxCsv) {
  # Create a high-level summary of the file index
  $rows = Import-Csv -Path $idxCsv
  $counts = $rows | Group-Object Type | Sort-Object Count -Descending
  $largest = $rows | Sort-Object { [int64]$_.SizeBytes } -Descending | Select-Object -First 25
  $newest = $rows | Sort-Object { [datetime]$_.LastWriteUtc } -Descending | Select-Object -First 25
  $summaryText = "files: $($rows.Count)`n`nby type:`n" +
    ($counts | ForEach-Object { "{0,6}  .{1}" -f $_.Count, $_.Name }) + "`n`nlargest 25:`n" +
    ($largest | ForEach-Object { "{0,10:N0}  {1}  {2}" -f $_.SizeBytes, $_.LastWriteUtc, (Get-DeloraRelativePath -Path $_.Path -Root $Root) }) + "`n`nnewest 25:`n" +
    ($newest | ForEach-Object { "{0,10:N0}  {1}  {2}" -f $_.SizeBytes, $_.LastWriteUtc, (Get-DeloraRelativePath -Path $_.Path -Root $Root) })
  Add-TOCEntry 'INDEX_SUMMARY' (Get-DeloraRelativePath -Path $idxCsv -Root $Root)
  Add-BundleSection 'INDEX_SUMMARY' $idxCsv $summaryText
}

$changesTxt = Join-Path $Root 'tools\indexes\Delora_changes.txt'
if (Test-Path $changesTxt) {
  $changesBody = Get-Content -Path $changesTxt -Raw -Encoding UTF8
  Add-TOCEntry 'INDEX_CHANGES' (Get-DeloraRelativePath -Path $changesTxt -Root $Root)
  Add-BundleSection 'INDEX_CHANGES' $changesTxt $changesBody
}

# SECTION 3: RECENT FILE PREVIEWS
# Find the most recently edited files and include a preview of their content.
$recentIndex = Import-Csv $idxCsv | Sort-Object { [datetime]$_.LastWriteUtc } -Descending | Select-Object -First 15
Add-TOCEntry 'RECENT' 'Previews of recently changed files'
foreach ($r in $recentIndex) {
    $rel = Get-DeloraRelativePath -Path $r.Path -Root $Root
    $id = "RECENT $rel"
    $previewContent = Get-Content -LiteralPath $r.Path -TotalCount 120 -Encoding UTF8 -ErrorAction SilentlyContinue
    Add-TOCEntry $id $rel
    Add-BundleSection $id $r.Path ($previewContent -join "`n")
}


# SECTION 4: KEY CONFIGURATION AND CODE FILES
# Add previews of important application configs, workflows, and source code.
# The logic here is to glob for files in specific locations and add them as sections.
$fileTargets = @(
  @{ IdPrefix = 'ST_';    Glob = 'SillyTavern\data\default-user\**\*.json' }
  @{ IdPrefix = 'WF_';    Glob = 'workflows\*.json' }
  @{ IdPrefix = 'TOOL_';  Glob = 'tools\*.ps1' }
)

foreach ($target in $fileTargets) {
  Get-ChildItem -Path (Join-Path $Root $target.Glob) -File -ErrorAction SilentlyContinue | ForEach-Object {
    # Get a preview of the file (head and tail)
    $fileContent = Get-DeloraFileHeadTail -Path $_.FullName -HeadLineCount $HeadLines -TailLineCount $TailLines
    # Protect any potential secrets before adding to the bundle
    $safeContent = Protect-DeloraSecrets -Text $fileContent
    # Create a unique section ID
    $sectionId = "$($target.IdPrefix)" + ($_.BaseName).ToUpperInvariant()
    $relPath = Get-DeloraRelativePath -Path $_.FullName -Root $Root
    Add-TOCEntry $sectionId $relPath
    Add-BundleSection $sectionId $_.FullName $safeContent
  }
}


# --- Finalization ---
# Prepend the Table of Contents to the beginning of the bundle file.
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$intro = @"
================================================================================
= Delora Bundle — $stamp
= Root = $Root
= This file contains curated extracts. See manifest CSV for metadata.
= Sections:
$(($TOC -join "`n"))
================================================================================

"@
$body = Get-Content -Path $bundlePath -Raw -Encoding UTF8
Set-Content -Path $bundlePath -Value ($intro + $body) -Encoding UTF8
Write-Host "Wrote bundle: $bundlePath"
Write-Host "Wrote manifest: $manifestPath"