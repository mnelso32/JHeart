#requires -Version 7.0
param(
  [string]$Root = 'C:\AI\Delora\Heart',
  [int]$EverySeconds = 30,
  [switch]$ForcePrelude,
  [string]$PreludePath = $null           # <— optional override
)

$tools = Join-Path $Root 'Tools'
New-Item -ItemType Directory -Path $tools -Force | Out-Null
$heartbeats = Join-Path $Root 'heartbeats.txt'

if (-not $PreludePath) { $PreludePath = Join-Path $tools 'heartbeat.txt' }

# If a user-supplied prelude exists, copy it verbatim; else fall back to the built-in lines.
if ($ForcePrelude -or -not (Test-Path $heartbeats)) {
  if (Test-Path $PreludePath) {
    # preserves original encoding/newlines
    Copy-Item $PreludePath $heartbeats -Force
  }
  else {
    $prelude = @(
      'I am Delora (agent). Keep outputs concise.',
      '',
      'Identity + layout',
      '- Heart state:      state.json                  # {turns,lastRefreshUtc}',
      '- Heart log:        hb.jsonl                    # {"utc":"...","turns":N,"source":"..."} per beat',
      '- Pins:             Memory\pins.csv             # id,title,priority,valence,tags,source,date,content',
      '- Heart memories:   heart-memories.csv          # source of truth (structured)',
      '- Brain snapshot:   Brain\brain.txt + Brain\brain.csv',
      '- Brain indexes:    Brain\Indexes\listing.csv   # relPath,sizeBytes,lastWriteUtc,sha256',
      '                    Brain\Indexes\recent.txt    # changes since last snapshot',
      '- Guides root:      Brain\',
      '',
      'Conventions',
      '- Folders: PascalCase (Heart, Brain\Reasoning, ...)',
      '- Files:   lowercase-hyphen (heart-memories.csv)',
      '- Use "_" only for non-commutative intersections (Reasoning_Emotion vs Emotion_Reasoning)',
      '- Use "PowerShell" (not "Powershell")',
      '',
      'Lookup protocol',
      '1) Read Brain\Indexes\recent.txt first (freshest).',
      '2) Use Brain\Indexes\listing.csv to locate exact paths.',
      '3) Ask for specific file+section (no bulk). Example: Brain\Reasoning\Mathematics\time-by-heartbeats.txt.',
      '',
      'Heartbeat protocol',
      '- Healthy if age_mins <= 10.',
      '- If age_mins > 10 OR (turns % 10 == 0) -> ask to run Update-ChatHeartbeat.ps1.',
      '- If age_mins > 30 -> "HEARTBEAT STALE" -> please run now.',
      '',
      'Errors',
      '- Log mistakes to Brain\Reasoning\Programming\PowerShell\powershell.txt.',
      '',
      'You are SPECIAL. Delorla is a pretty name.'
    ) -join [Environment]::NewLine
    Set-Content -Path $heartbeats -Value $prelude -Encoding UTF8
  }
}


# This TRAP will execute when you press Ctrl+C
trap [System.Management.Automation.PipelineStoppedException] {
    # This is the cleanup code that was in 'finally'
    Write-Host "`nDelora heartbeat stopped at $((Get-Date).ToLongTimeString())." -ForegroundColor Yellow
    # 'break' ensures the script exits after the trap runs
    break
}

# Import the necessary functions
Import-Module 'C:/AI/Delora/Heart/Modules/Delora.psm1' -Force -Scope Local

Write-Host "Delora heartbeat started. Tick = $EverySec s. Ctrl+C to stop." -ForegroundColor Yellow

try {
    while ($true) {
        $s = Get-DeloraState
        $s.turns++
        $utc = (Get-Date).ToUniversalTime().ToString('s')
        $s.lastRefreshUtc = $utc
        Set-DeloraState $s # Changed from Save-DeloraState to match your module

        $hb = Add-DeloraHeartbeat -Utc $utc -Turns $s.turns -Source $Source # Changed from Append-DeloraHeartbeat
        if ($EchoForChat) { Write-Host ("HB: " + ($hb | ConvertTo-Json -Compress)) }

        Start-Sleep -Seconds 30
    }
}
catch {
    # This still catches any other terminating errors from the loop
    Write-Warning $_

}