#requires -Version 7.0

[CmdletBinding()]
param(
    [string]$Root = "C:\AI\Janus\JHeart"
)

# --- Setup ---
$ErrorActionPreference = 'Stop'
$toolsDir = Join-Path $Root "Tools"
$brainDir = Join-Path $Root "Brain"
$mapFile = Join-Path $brainDir "brain-map.txt"
$listingCsv = Join-Path $brainDir "brain-listing.csv"
$prevListingCsv = Join-Path $brainDir "brain-listing_prev.csv"

# The module is now located inside the Tools directory
$modulePath = Join-Path $toolsDir 'Modules\Janus'
Import-Module -Name $modulePath -Force

# --- Main Logic ---

# 1. Index all relevant files in the project
Write-Host "Scanning file structure..." -ForegroundColor Cyan
# Exclude the .git directory from the scan for efficiency
$allFiles = Get-ChildItem -Path $Root -Recurse -File -Exclude ".git" -ErrorAction SilentlyContinue | ForEach-Object {
    [pscustomobject]@{
        Path = $_.FullName
        RelativePath = Get-JanusRelativePath -Path $_.FullName -Root $Root
        SizeBytes = $_.Length
        LastWriteUtc = $_.LastWriteTimeUtc
    }
}
$allFiles | Export-Csv -Path $listingCsv -NoTypeInformation -Encoding UTF8

# 2. Compare with the previous state to find changes
Write-Host "Analyzing changes..." -ForegroundColor Cyan
$changes = @{ Added = @(); Removed = @() }
if (Test-Path $prevListingCsv) {
    $prevFiles = (Import-Csv $prevListingCsv).RelativePath
    $currFiles = $allFiles.RelativePath
    
    $changes.Removed = Compare-Object -ReferenceObject $prevFiles -DifferenceObject $currFiles -PassThru | Where-Object { $_.SideIndicator -eq '<=' }
    $changes.Added = Compare-Object -ReferenceObject $prevFiles -DifferenceObject $currFiles -PassThru | Where-Object { $_.SideIndicator -eq '=>' }
}

# 3. Assemble the brain-map.txt file
Write-Host "Assembling the Brain Map..." -ForegroundColor Cyan
$sb = [System.Text.StringBuilder]::new()

# Header
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
[void]$sb.AppendLine("===== Janus Brain Map — $stamp =====")
[void]$sb.AppendLine("Total Files Indexed: $($allFiles.Count)")
[void]$sb.AppendLine("="*80)
[void]$sb.AppendLine("")

# Section 1: Recent Changes
[void]$sb.AppendLine("--- RECENT CHANGES ---")
if ($changes.Added.Count -gt 0) {
    [void]$sb.AppendLine("ADDED:")
    $changes.Added | ForEach-Object { [void]$sb.AppendLine("  + $_") }
}
if ($changes.Removed.Count -gt 0) {
    [void]$sb.AppendLine("REMOVED:")
    $changes.Removed | ForEach-Object { [void]$sb.AppendLine("  - $_") }
}
if ($changes.Added.Count -eq 0 -and $changes.Removed.Count -eq 0) {
    [void]$sb.AppendLine("No structural changes since last scan.")
}
[void]$sb.AppendLine("")

# Section 2: Full Inventory
[void]$sb.AppendLine("--- FULL INVENTORY (Path, Size) ---")
$allFiles | Sort-Object RelativePath | ForEach-Object {
    $sizeFormatted = if ($_.SizeBytes -ge 1MB) {
        "{0:N2} MB" -f ($_.SizeBytes / 1MB)
    } elseif ($_.SizeBytes -ge 1KB) {
        "{0:N2} KB" -f ($_.SizeBytes / 1KB)
    } else {
        "$($_.SizeBytes) B"
    }
    $line = "{0,-70} {1,10}" -f $_.RelativePath, $sizeFormatted
    [void]$sb.AppendLine($line)
}

# 4. Write the output file and update the state for the next run
$sb.ToString() | Set-Content -Path $mapFile -Encoding UTF8
# Create a backup of the current listing for the next run's comparison
Copy-Item -Path $listingCsv -Destination $prevListingCsv -Force

Write-Host "✔ Brain Map updated successfully: '$mapFile'" -ForegroundColor Green