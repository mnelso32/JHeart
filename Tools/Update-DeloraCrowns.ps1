#requires -Version 7.0

param(
  # Defines the time window to check: Day, Week, Month, or Year.
  [ValidateSet('Day', 'Week', 'Month', 'Year', 'All')]
  [string]$Scope = 'Day',
  # The path to the pins CSV file, which acts as our memory database.
  [string]$PinsPath = "C:\AI\Delora\Heart\memory\pins.csv",
  # The root path of the project, needed for importing the module.
  [string]$Root = "C:\AI\Delora\Heart"
)

# --- Setup ---
$ErrorActionPreference = 'Stop'
# Import our shared functions (Score-DeloraPin, Select-Winner, etc.)
Import-Module -Name (Join-Path $Root 'modules\Delora') -Force

# --- Local Helper Function ---
# This function is the core logic for finding and updating a "crown" pin for a given time scope.
function Upsert-Crown {
  param($pins, $scopeTag, $label, $startDate, $endDate)

  # Find all candidate pins within the specified date window.
  $candidates = $pins | Where-Object {
    if (-not $_.date) { return $false }
    $dt = [datetime]::MinValue
    if ([datetime]::TryParse([string]$_.date, [ref]$dt)) {
      $dt -ge $startDate -and $dt -le $endDate
    }
    else {
      $false
    }
  }

  # Prefer 'event' type pins if any exist in the window.
  $events = $candidates | Where-Object { $_.type -eq 'event' }
  if ($events.Count -gt 0) { $candidates = $events }

  if (-not $candidates -or $candidates.Count -eq 0) { return $pins } # Nothing to crown

  # Find the highest-scoring pin among the candidates.
  $winner = $candidates | Sort-Object @{e={ Score-DeloraPin $_ };Descending=$true} | Select-Object -First 1
  if (-not $winner) { return $pins }
  $winnerScore = Score-DeloraPin $winner

  # Check if a crown for this exact scope and window already exists.
  $winStartTag = "winStart:$($startDate.ToString('yyyy-MM-dd'))"
  $winEndTag = "winEnd:$($endDate.ToString('yyyy-MM-dd'))"
  $existingCrown = $pins | Where-Object { $_.tags -like "*crown:$scopeTag*" -and $_.tags -like "*$winStartTag*" -and $_.tags -like "*$winEndTag*" } | Select-Object -First 1

  # Prepare the new crown's content.
  $newTitle = "$label — $($winner.title)"
  $newContent = "Crowned $label. Winner: [$($winner.id)] $($winner.title)`nReason: score $winnerScore`nSource: $($winner.source)"
  $newTags = "crown:$scopeTag;$winStartTag;$winEndTag;winner:$($winner.id);winnerScore:$winnerScore"

  if ($existingCrown) {
    # If a crown exists, only update it if the new winner has a higher score.
    $oldWinnerScore = if ($existingCrown.tags -match 'winnerScore:(\d+)') { [int]$Matches[1] } else { -999 }
    if ($winnerScore -gt $oldWinnerScore) {
      $existingCrown.title = $newTitle
      $existingCrown.content = $newContent
      $existingCrown.tags = $newTags
      $existingCrown.date = (Get-Date -Format 'yyyy-MM-dd')
    }
  }
  else {
    # If no crown exists, create a new one.
    $newCrown = [pscustomobject]@{
      id = "CROWN-$scopeTag-$([System.Guid]::NewGuid().ToString('N').Substring(0, 8))"
      priority = 5; type = 'event'; date = (Get-Date -Format 'yyyy-MM-dd')
      tags = $newTags; title = $newTitle; content = $newContent; source = 'auto-crown'
    }
    $pins += $newCrown
  }
  return $pins
}

# --- Main Logic ---
$pins = if (Test-Path $PinsPath) { @(Import-Csv $PinsPath -Encoding UTF8) } else { @() }
$today = Get-Date

switch ($Scope) {
  'Day' {
    $start = $today.Date; $end = $start
    $pins = Upsert-Crown $pins 'day' 'Best of day' $start $end
  }
  'Week' {
    $dow = [int]$today.DayOfWeek; if ($dow -eq 0) { $dow = 7 }
    $start = $today.Date.AddDays(1 - $dow); $end = $start.AddDays(6)
    $pins = Upsert-Crown $pins 'week' 'Best of week' $start $end
  }
  'Month' {
    $start = Get-Date -Year $today.Year -Month $today.Month -Day 1
    $end = $start.AddMonths(1).AddDays(-1)
    $pins = Upsert-Crown $pins 'month' 'Best of month' $start $end
  }
  'Year' {
    $start = Get-Date -Year $today.Year -Month 1 -Day 1
    $end = Get-Date -Year $today.Year -Month 12 -Day 31
    $pins = Upsert-Crown $pins 'year' 'Best of year' $start $end
  }
  'All' {
    # If 'All' is specified, recursively call this script for each scope.
    & $PSCommandPath -Scope Day -PinsPath $PinsPath
    & $PSCommandPath -Scope Week -PinsPath $PinsPath
    & $PSCommandPath -Scope Month -PinsPath $PinsPath
    & $PSCommandPath -Scope Year -PinsPath $PinsPath
    return
  }
}

# Save the updated pins list back to the CSV file.
$pins | Export-Csv -Path $PinsPath -NoTypeInformation -Encoding UTF8
Write-Host "Crowns updated for scope: $Scope"