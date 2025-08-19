#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Root = "C:\AI\Janus\JHeart"
)
# --- Setup ---
$ErrorActionPreference = "Stop"
$toolsDir = Join-Path $Root "Tools"
$memDir = Join-Path $Root "Heart-Memories"
$pinsCsv = Join-Path $memDir "pins.csv"
$chatsDir = Join-Path $Root "chats" # Assuming a top-level chats folder for now
$outTxt = Join-Path $memDir "janus-memory.txt"
# Import the shared module
$modulePath = Join-Path $toolsDir 'Modules\Janus'
Import-Module -Name $modulePath -Force
# Create directories if they don't exist
New-Item -ItemType Directory -Force -Path $memDir, $chatsDir | Out-Null
# Seed pins.csv if it's missing
if (-not (Test-Path $pinsCsv)) {
    '@'
id,priority,type,date,tags,title,content,source
J-SEED-0001,5,rule,,ops;memory,"How to edit pins","Edit Heart-Memories/pins.csv and rerun this script to regenerate.",local
'@' | Set-Content -Path $pinsCsv -Encoding UTF8
}
# --- Budget and Output Management ---
[int]$script:BudgetKB = 500
[int]$script:budgetBytes = $script:BudgetKB * 1024
$sb = [System.Text.StringBuilder]::new()
# --- Data Loading ---
Write-Host "Loading and scoring memory pins..." -ForegroundColor Cyan
$pins = Import-Csv $pinsCsv
$pinsScored = $pins | ForEach-Object {
    $_ | Add-Member -NotePropertyName "score" -NotePropertyValue (Measure-JanusPinScore $_) -PassThru # Assumes Measure-JanusPinScore in module
}
# --- Compose Text File ---
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
[void]$sb.AppendLine("===== Janus Core Memory — $stamp =====")
[void]$sb.AppendLine("== Root: $Root")
[void]$sb.AppendLine("=================================================================")
[void]$sb.AppendLine("")
# -- CORE MEMORY (top-scored first) --
$coreMemory = $pinsScored | Sort-Object @{Expression='score';Descending=$true}, @{Expression='id';Ascending=$true}
foreach ($pin in $coreMemory) {
    # Simple budget check for each pin
    if ($sb.Length -gt $script:budgetBytes) {
        [void]$sb.AppendLine("...(truncated: memory file hit ~$($script:BudgetKB)KB budget)...")
        break
    }
    [void]$sb.AppendLine(("[{0}] (prio {1}) {2}" -f $pin.id, $pin.priority, $pin.title))
    if ($pin.date)    { [void]$sb.AppendLine(("  date: {0}" -f $pin.date)) }
    if ($pin.tags)    { [void]$sb.AppendLine(("  tags: {0}" -f $pin.tags)) }
    if ($pin.content) { [void]$sb.AppendLine(("  content: {0}" -f $pin.content)) }
    if ($pin.source)  { [void]$sb.AppendLine(("  source: {0}" -f $pin.source)) }
    [void]$sb.AppendLine("")
}
# --- Finalize and Write Output ---
$sb.ToString() | Set-Content -Path $outTxt -Encoding UTF8
Write-Host "✔ Wrote Janus memory file: $outTxt" -ForegroundColor Green
