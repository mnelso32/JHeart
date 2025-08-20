# This script runs in a continuous loop to give Janus a "pulse" every minute.

param(
    [int]$IntervalSeconds = 60
)

# --- CORRECTED SECTION: Use the script's own location to find the state script ---
# $PSScriptRoot is an automatic variable that contains the path to the current script's directory.
$updateScriptPath = Join-Path $PSScriptRoot "Update-State.ps1"
# --- End of corrected section ---

Write-Host "Starting Janus heartbeat loop. Pulse interval: $IntervalSeconds seconds." -ForegroundColor Cyan

while ($true) {
    try {
        & $updateScriptPath
    }
    catch {
        Write-Warning "Heartbeat pulse failed: $_.Exception.Message"
    }
    Start-Sleep -Seconds $IntervalSeconds
}