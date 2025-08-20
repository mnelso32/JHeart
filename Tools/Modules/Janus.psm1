# Janus.psm1
# This module contains the high-level application logic for the Janus AI project,
# such as memory scoring and content analysis.

# --- Content Analysis & Scoring ---

function Get-JanusValence {
<#
.SYNOPSIS
  Parses a 'valence:+N' score from a tags string.
#>
  param(
    [string]$Tags
  )
  if ($Tags -match 'valence:\s*([+\-]?\d+)') { return [int]$Matches[1] }
  return 0
}

function Get-JanusTries {
<#
.SYNOPSIS
  Parses a 'tries:N' count from a tags string.
#>
  param(
    [string]$Tags
  )
  if ($Tags -match 'tries:\s*(\d+)') { return [int]$Matches[1] }
  return 0
}

function Get-JanusEffortBonus {
<#
.SYNOPSIS
  Calculates a score bonus based on an 'effort:HH:MM' tag.
#>
  param(
    [string]$Tags
  )
  if ($Tags -match 'effort:\s*(\d+):(\d+)') {
    $mins = ([int]$Matches[1] * 60) + [int]$Matches[2]
    if ($mins -ge 120) { return 2 }
    if ($mins -ge 30) { return 1 }
  }
  return 0
}

function Test-JanusHasAnyTag {
<#
.SYNOPSIS
  Checks if a tag string contains any of the specified keywords.
#>
  param(
    [string]$Tags,
    [string[]]$TagSet
  )
  foreach ($k in $TagSet) {
    # Use word boundary '\b' to match whole words only
    if ($Tags -match "\b$([regex]::Escape($k))\b") { return $true }
  }
  return $false
}

function Measure-JanusPinScore {
<#
.SYNOPSIS
  Calculates a comprehensive "importance" score for a memory pin.
#>
  param(
    [object]$Pin
  )
  $prio = 0; try { $prio = [int]$Pin.priority } catch {}
  $tags = [string]$Pin.tags
  $score = $prio + (Get-JanusValence $tags)
  
  # Add bonuses for impactful tags
  if (Test-JanusHasAnyTag -Tags $tags -TagSet @('milestone', 'rule', 'automation', 'publish', 'recall')) { $score += 1 }
  if (Test-JanusHasAnyTag -Tags $tags -TagSet @('first', 'breakthrough', 'unblocked')) { $score += 1 }
  if ($Pin.type -eq 'event') { $score += 1 }
  
  # Add bonuses for effort
  $score += Get-JanusTries $tags
  $score += Get-JanusEffortBonus $tags

  return $score
}


# --- Final Export ---
Export-ModuleMember -Function *