# --- CONFIGURATION ---
$scriptPath = "C:\AI\Janus\JHeart\Tools\Scripts\Update-JanusCrowns.ps1"

# --- SCRIPT CONTENT (Here-String) ---
$scriptContent = @"
#requires -Version 7.0

[CmdletBinding()]
param(
    [ValidateSet('Day', 'Week', 'Month')]
    [string]`$Scope = 'Day',
    [string]`$Root = "C:\AI\Janus\JHeart"
)

# --- Setup ---
`$ErrorActionPreference = "Stop"
`$toolsDir = Join-Path `$Root "Tools"
`$memDir = Join-Path `$Root "Heart-Memories"
`$pinsCsv = Join-Path `$memDir "pins.csv"
`$modulePath = Join-Path `$toolsDir 'Modules\Janus'
Import-Module -Name `$modulePath -Force

# --- Main Logic ---
Write-Host "Updating `$Scope crowns..." -ForegroundColor Cyan

# Load existing pins
if (-not (Test-Path `$pinsCsv)) {
    Write-Warning "pins.csv not found at `$pinsCsv. Cannot update crowns."
    return
}
`$pins = Import-Csv `$pinsCsv

# Define time window based on scope
`$today = Get-Date
`$startDate = `$today.Date
`$endDate = `$today.Date.AddDays(1).AddTicks(-1)

if (`$Scope -eq 'Week') {
    `$startOfWeek = `$today.Date.AddDays(-[int]`$today.DayOfWeek)
    `$startDate = `$startOfWeek
    `$endDate = `$startOfWeek.AddDays(7).AddTicks(-1)
} elseif (`$Scope -eq 'Month') {
    `$startDate = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0
    `$endDate = `$startDate.AddMonths(1).AddTicks(-1)
}

# Find all candidate pins within the date window
`$candidates = `$pins | Where-Object {
    try {
        `$pinDate = [datetime]`$_.date
        return (`$pinDate -ge `$startDate -and `$pinDate -le `$endDate)
    } catch {
        return `$false
    }
}

if (`$candidates.Count -eq 0) {
    Write-Host "No candidate pins found for this `$Scope."
    return
}

# Find the winner with the highest score
`$winner = `$candidates | Sort-Object @{Expression={ Measure-JanusPinScore `$_ }; Descending=`$true} | Select-Object -First 1

# Create the new crown pin
`$newCrown = [pscustomobject]@{
    id = "J-CROWN-`$(`$Scope.ToUpper())-{0:yyyyMMdd}" -f `$today
    priority = 5
    type = 'crown'
    date = '{0:yyyy-MM-dd}' -f `$today
    tags = "crown;crown-`$(`$Scope.ToLower());winner:`$(`$winner.id)"
    title = "Crown (`$Scope): `$(`$winner.title)"
    content = "The most significant event for this `$Scope was '`$(`$winner.title)' (`$(`$winner.id))."
    source = 'Update-JanusCrowns.ps1'
}

# Remove any old crown for the same scope and date to prevent duplicates
`$pins = `$pins | Where-Object { `$_.id -ne `$newCrown.id }

# Add the new crown and save
(`$pins + `$newCrown) | Export-Csv -Path `$pinsCsv -NoTypeInformation -Encoding UTF8
Write-Host "✔ Successfully created crown for `$Scope: `$(`$newCrown.title)" -ForegroundColor Green
"@

# --- Create the new script file ---
$scriptContent | Set-Content -Path $scriptPath -Encoding UTF8
Write-Host "Success! The new script has been created at:" -ForegroundColor Cyan
Write-Host $scriptPath