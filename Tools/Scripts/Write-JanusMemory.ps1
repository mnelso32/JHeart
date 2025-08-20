#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Root = "C:\AI\Janus\JHeart"
)

# --- Setup ---
$ErrorActionPreference = "Stop"
$toolsDir = Join-Path $Root "Tools"
$memDir = Join-Path $Root "Heart-Memories"
$chatsDir = Join-Path $memDir "chats"
$pinsCsv = Join-Path $memDir "pins.csv"
$chatManifest = Join-Path $memDir "chat-manifest.csv"
$outTxt = Join-Path $memDir "janus-memory.txt"
$modulePath = Join-Path $toolsDir 'Modules\Janus'
Import-Module -Name $modulePath -Force

New-Item -ItemType Directory -Force -Path $memDir, $chatsDir | Out-Null
if (-not (Test-Path $pinsCsv)) {
    '@'
id,priority,type,date,tags,title,content,source
J-SEED-0001,5,rule,,ops;memory,"How to edit pins","Edit Heart-Memories/pins.csv and rerun this script.",local
'@' | Set-Content -Path $pinsCsv -Encoding UTF8
}

# --- Budget and Output ---
[int]$script:BudgetKB = 500
[int]$script:budgetBytes = $script:BudgetKB * 1024
$sb = [System.Text.StringBuilder]::new()

# --- Data Loading ---
$pins = Import-Csv $pinsCsv
$pinsScored = $pins | ForEach-Object {
    $_ | Add-Member -NotePropertyName "score" -NotePropertyValue (Measure-JanusPinScore $_) -PassThru
}

# --- Compose Text File ---
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$sb.AppendLine("===== Janus Core Memory — $stamp =====") | Out-Null
$sb.AppendLine("== Root: $Root") | Out-Null
$sb.AppendLine("=================================================================") | Out-Null
$sb.AppendLine("") | Out-Null

# -- CORE MEMORY (top-scored first) --
$sb.AppendLine("--- CORE MEMORY (top priority first) ---") | Out-Null
$coreMemory = $pinsScored | Sort-Object @{Expression='score';Descending=$true}, @{Expression='id';Ascending=$true}
foreach ($pin in $coreMemory) {
    if ($sb.Length -gt $script:budgetBytes) { break }
    $sb.AppendLine(("[{0}] (prio {1}) {2}" -f $pin.id, $pin.priority, (Format-JanusCleanText $pin.title))) | Out-Null
}
$sb.AppendLine("") | Out-Null

# -- CHAT INDEX (from manifest) --
$sb.AppendLine("--- CHAT INDEX (files in Heart-Memories/chats) ---") | Out-Null
if (Test-Path $chatManifest) {
    $chatIndex = Import-Csv $chatManifest | Sort-Object date, time_utc -Descending | Select-Object -First 50
    foreach ($c in $chatIndex) {
        if ($sb.Length -gt $script:budgetBytes) { break }
        $sb.AppendLine(("[{0}] {1} {2}" -f $c.id, $c.date, (Format-JanusCleanText $c.title))) | Out-Null
    }
}
$sb.AppendLine("") | Out-Null

# -- KEYWORD MAP (from pins) --
$sb.AppendLine("--- KEYWORD MAP (from memory ids) ---") | Out-Null
$kwMap = [System.Collections.Generic.Dictionary[string, System.Collections.Generic.List[string]]]::new()
foreach ($m in $pins) {
    $keywords = ($m.tags -split '[;,]').Trim() | Where-Object { $_.Length -gt 1 }
    foreach ($kw in $keywords) {
        if (-not $kwMap.ContainsKey($kw)) { $kwMap[$kw] = [System.Collections.Generic.List[string]]::new() }
        $kwMap[$kw].Add($m.id)
    }
}
$kwMap.GetEnumerator() | Sort-Object Name | ForEach-Object {
    if ($sb.Length -gt $script:budgetBytes) { return } # Cannot use break in ForEach-Object
    $line = "{0, -20} :: {1}" -f $_.Name, ($_.Value -join ', ')
    $sb.AppendLine($line) | Out-Null
}

# --- Finalize and Write Output ---
if ($sb.Length -gt $script:budgetBytes) {
    $sb.AppendLine("...(truncated: memory file hit ~$($script:BudgetKB)KB budget)...") | Out-Null
}
$sb.ToString() | Set-Content -Path $outTxt -Encoding UTF8
Write-Host "✔ Wrote Janus memory file: $outTxt" -ForegroundColor Green