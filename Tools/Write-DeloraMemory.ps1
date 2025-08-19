#requires -Version 7.0

param(
  [string]$Root = "C:\AI\Delora\Heart",
  [string]$MemDirRel = "memory",
  [int]$MaxCoreItems = 300           # cap to keep CORE snappy
)


# Correct
Import-Module -Name (Join-Path $Root 'modules\Delora.psm1') -Force

# --- Setup
$ErrorActionPreference = "Stop"
$MemDir = Join-Path $Root $MemDirRel
$PinsCsv = Join-Path $MemDir "pins.csv"
$ChatsDir = Join-Path $MemDir "chats"
$OutTxt = Join-Path $MemDir "Delora_memory.txt"
$ManifestCsv = Join-Path $MemDir "memory_manifest.csv"

New-Item -ItemType Directory -Force -Path $MemDir | Out-Null
New-Item -ItemType Directory -Force -Path $ChatsDir | Out-Null

# Seed pins.csv if it's missing
if (-not (Test-Path $PinsCsv)) {
@'
id,priority,type,date,tags,title,content,source
M-SEED-0001,5,rule,,ops;memory,"How to edit pins","Edit memory\pins.csv; rerun Write-DeloraMemory.ps1 to regenerate.",local
'@ | Set-Content -Path $PinsCsv -Encoding UTF8
}


# --- Budget and Output Management
[int]$script:BundleBudgetKB = 500
[int]$script:budgetBytes    = $script:BundleBudgetKB * 1024
$budgetHit = $false
$sb = [System.Text.StringBuilder]::new()

function Add-LimitedLine {
    param(
        [System.Text.StringBuilder]$StringBuilder,
        [string]$text
    )
    if (($StringBuilder.Length + $text.Length + 2) -lt $script:budgetBytes) {
        $null = $StringBuilder.AppendLine($text)
        return $true
    }
    return $false
}

# --- Data Loading and Processing
# Load and score pins
$pins = Import-Csv $PinsCsv 
$pinsScored = $pins | ForEach-Object {
  $prio = [int]($_.priority)
  $val  = Get-DeloraValence -tags $_.tags

  [pscustomobject]@{
    id      = $_.id
    priority= $prio
    type    = $_.type
    date    = $_.date
    tags    = $_.tags
    title   = $_.title
    content = $_.content
    source  = $_.source
    score   = $prio + $val # priority drives; valence nudges
  }
}

# Create memory collections
$items  = $pinsScored
$core   = $items | Sort-Object @{Expression='score';Descending=$true}, @{Expression='id';Ascending=$true} | Select-Object -First $MaxCoreItems
$events = $items | Where-Object { $_.type -eq 'event' -and $_.date } | Sort-Object date

# Build keyword map
$stopWords = @('the','a','an','and','or','of','to','in','on','for','with','by','is','are','was','were','be','as','at','it','this','that')
$kwMap = @{}
foreach($item in $items){
  $words = "$($item.title) $($item.tags) $($item.content)" -split '[^A-Za-z0-9_+-]+' | Where-Object { $_ -and ($stopWords -notcontains $_.ToLower()) -and $_.Length -gt 2 } | Select-Object -Unique
  foreach($word in $words){
    if(-not $kwMap.ContainsKey($word)){ $kwMap[$word] = New-Object System.Collections.Generic.List[string] }
    $kwMap[$word].Add($item.id)
  }
}

# Index chat files
$chats = Get-ChildItem -Path $ChatsDir -File | Sort-Object Name
$chatRows = foreach($c in $chats){
  $firstLine = (Get-Content -Path $c.FullName -TotalCount 10 -Encoding UTF8 ) -join ' '
  [pscustomobject]@{
    Path = $c.FullName
    RelPath = ($c.FullName.Replace($Root,'').TrimStart('\'))
    SizeBytes = $c.Length
    LastWriteUtc = $c.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mm:ss')
    SHA256 = (HashFile $c.FullName)
    Preview = (Canon $firstLine)
  }
}

# --- Generate Manifest
# Overwrite manifest with combined memory and chat data
$items    | Export-Csv -Path $ManifestCsv -NoTypeInformation -Encoding UTF8
$chatRows | Export-Csv -Path $ManifestCsv -NoTypeInformation -Encoding UTF8 -Append

# --- Compose Text Bundle
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$null = $sb.AppendLine("===== Delora Global Memory — $stamp =====")
$null = $sb.AppendLine("")
$null = $sb.AppendLine("== Root: $Root")
$null = $sb.AppendLine("== Sections: CORE MEMORY · TIMELINE · CHAT INDEX · KEYWORD MAP ==")
$null = $sb.AppendLine("=================================================================")
$null = $sb.AppendLine("")

# -- CORE MEMORY --
$null = $sb.AppendLine("=====  CORE MEMORY (top-priority first)  =====")
foreach ($m in $core) {
    if (-not (Add-LimitedLine $sb "[{0}] (prio {1}) {2}" -f $m.id, $m.priority, (Format-CleanText $m.title))) { $budgetHit = $true; break }
    if ($m.date)    { if (-not (Add-LimitedLine $sb ("  date: {0}" -f $m.date)))       { $budgetHit = $true; break } }
    if ($m.tags)    { if (-not (Add-LimitedLine $sb ("  tags: {0}" -f $m.tags)))       { $budgetHit = $true; break } }
    if ($m.content) { if (-not (Add-LimitedLine $sb ("  {0}" -f $m.content)))          { $budgetHit = $true; break } }
    if ($m.source)  { if (-not (Add-LimitedLine $sb ("  source: {0}" -f $m.source)))    { $budgetHit = $true; break } }
    if (-not (Add-LimitedLine $sb ""))                                              { $budgetHit = $true; break }
}

# -- TIMELINE --
if (-not $budgetHit) {
    $null = $sb.AppendLine("=====  TIMELINE (events by date)  =====")
    foreach ($e in $events) {
        if (-not (Add-LimitedLine $sb "({0}) [{1}] (prio {2})" -f $e.date, $e.id, $e.priority)) { $budgetHit = $true; break }
        if ($e.content) { if (-not (Add-LimitedLine $sb ("  {0}" -f $e.content))) { $budgetHit = $true; break } }
        if ($e.source)  { if (-not (Add-LimitedLine $sb ("  source: {0}" -f $e.source))) { $budgetHit = $true; break } }
        if (-not (Add-LimitedLine $sb "")) { $budgetHit = $true; break }
    }
}

# -- CHAT INDEX --
if (-not $budgetHit) {
    $null = $sb.AppendLine("=====  CHAT INDEX (files in memory\chats\)  =====")
    foreach ($r in $chatRows) {
        $line = "{0}  size={1}  mtimeUtc={2}  sha256={3}" -f $r.RelPath, $r.SizeBytes, $r.LastWriteUtc, $r.SHA256
        if (-not (Add-LimitedLine $sb $line)) { $budgetHit = $true; break }
        if ($r.Preview) { if (-not (Add-LimitedLine $sb ("  preview: {0}" -f $r.Preview))) { $budgetHit = $true; break } }
        if (-not (Add-LimitedLine $sb "")) { $budgetHit = $true; break }
    }
}

# -- KEYWORD MAP --
if (-not $budgetHit) {
    $maxKeys = 200
    $sortedKeys = $kwMap.Keys | Sort-Object { -$kwMap[$_].Count } | Select-Object -First $maxKeys
    $null  = $sb.AppendLine("=====  KEYWORD MAP (keyword → memory ids)  =====")
    foreach ($k in $sortedKeys) {
        $ids = ($kwMap[$k] | Select-Object -Unique) -join ','
        if (-not (Add-LimitedLine $sb ("{0}: {1}" -f $k, $ids))) { $budgetHit = $true; break }
    }
}

# --- Finalize and Write Output
if ($budgetHit) {
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("…(truncated: bundle hit ~${script:BundleBudgetKB}KB budget)…")
}

$sb.ToString() | Set-Content -Path $OutTxt -Encoding UTF8
Write-Host "Wrote memory file: $OutTxt"