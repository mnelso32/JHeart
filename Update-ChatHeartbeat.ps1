param(
    [int]$Turns = 0,
    [string]$Source = "GLM"
)

# Path to your Heart folder
$heartRoot = "C:\AI\Delora\Heart"
$hbFile = Join-Path $heartRoot "hb.jsonl"
$stateFile = Join-Path $heartRoot "state.json"

# Ensure Heart folder exists
if (-not (Test-Path $heartRoot)) {
    New-Item -ItemType Directory -Path $heartRoot | Out-Null
}

# Make heartbeat entry
$utcNow = (Get-Date).ToUniversalTime().ToString("s") + "Z"
$entry = @{ utc = $utcNow; turns = $Turns; source = $Source } | ConvertTo-Json -Compress

# Append to hb.jsonl
Add-Content -Path $hbFile -Value $entry

# Update state.json (overwrite with latest info)
$state = @{ turns = $Turns; lastRefreshUtc = $utcNow }
$state | ConvertTo-Json -Depth 3 | Set-Content -Path $stateFile -Encoding UTF8
