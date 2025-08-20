#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Title,
    [string]$Tags = "chat",
    [string]$Root = "C:\AI\Janus\JHeart"
)
# --- Setup ---
$ErrorActionPreference = "Stop"
$memDir = Join-Path $Root "Heart-Memories"
$chatsDir = Join-Path $memDir "chats"
$chatManifest = Join-Path $memDir "chat-manifest.csv"
$scriptsDir = Join-Path $Root "Tools\Scripts"
# --- Main Logic ---
$content = Get-Clipboard
if ([string]::IsNullOrWhiteSpace($content)) {
    throw "Clipboard is empty. Please copy the chat content first."
}
# Use the provided title or grab the first non-empty line as the title
if ([string]::IsNullOrWhiteSpace($Title)) {
    $Title = ($content -split '\r?\n' | Where-Object { $_ -notmatch '^\s*$' } | Select-Object -First 1).Trim()
}
$now = Get-Date
$id = "J-CHAT-{0:yyyyMMddHHmmss}" -f $now
$date = '{0:yyyy-MM-dd}' -f $now
$time_utc = '{0:HH:mm:ss}' -f $now.ToUniversalTime()
$fileName = "$id.txt"
$filePath = Join-Path $chatsDir $fileName
# Save the chat content to a new file
$content | Set-Content -Path $filePath -Encoding UTF8
Write-Host "✔ Saved chat to $filePath" -ForegroundColor Green
# Update the chat manifest
$manifestEntry = [pscustomobject]@{
    id = $id
    date = $date
    time_utc = $time_utc
    tags = $Tags
    title = $Title
    path = $filePath
}
$manifestEntry | Export-Csv -Path $chatManifest -Append -NoTypeInformation -Encoding UTF8
Write-Host "✔ Updated chat manifest." -ForegroundColor Green
# --- Trigger a rebuild to incorporate the new chat ---
Write-Host "
Triggering a rebuild to update brain files..." -ForegroundColor Cyan
& (Join-Path $scriptsDir "Build-Janus.ps1") -SkipIndexes # Skip full re-index for speed
