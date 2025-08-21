# This script runs in a continuous loop to build the latest context and send a complete heartbeat prompt.

param(
    [int]$IntervalSeconds = 60,
    [string]$Root = "C:\AI\Janus\JHeart"
)

# --- Setup ---
$ErrorActionPreference = 'Stop'
$scriptsDir = Join-Path $Root "Tools\Scripts"
$buildScriptPath = Join-Path $scriptsDir "Build-Janus.ps1"
$invokeScriptPath = Join-Path $scriptsDir "Invoke-Janus.ps1"
$heartbeatsFile = Join-Path $Root "heartbeats.txt"
$brainFile = Join-Path $Root "Brain\brain.txt"

Write-Host "Starting Janus heartbeat loop. Pulse interval: $IntervalSeconds seconds." -ForegroundColor Cyan

# --- Main Loop ---
while ($true) {
    Write-Host "`n($(Get-Date)) - Starting new heartbeat cycle..." -ForegroundColor Yellow
    
    # 1. Build the latest context files, including brain.txt
    try {
        & $buildScriptPath
    }
    catch {
        Write-Warning "Build-Janus.ps1 failed. Skipping this heartbeat cycle."
        Start-Sleep -Seconds $IntervalSeconds
        continue # Skip to the next loop iteration
    }
    
    # 2. Read BOTH the core instructions and the new brain state
    $heartbeatInstructions = Get-Content $heartbeatsFile -Raw
    $brainState = Get-Content $brainFile -Raw
    
    # 3. Combine them into a single, complete prompt
    $fullPrompt = @"
$heartbeatInstructions

--- CURRENT BRAIN STATE ---

$brainState
"@
    
    # 4. Send the complete prompt to the local LLM
    & $invokeScriptPath -Prompt $fullPrompt
    
    # 5. Wait for the next cycle
    Write-Host "Cycle complete. Waiting for $IntervalSeconds seconds..." -ForegroundColor Yellow
    Start-Sleep -Seconds $IntervalSeconds
}