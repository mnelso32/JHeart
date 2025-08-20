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
$logicModulePath = Join-Path $Root 'Tools\Modules\Janus.psm1'
$toolsModulePath = Join-Path $Root 'Tools\Modules\Janus.Tools.psm1'
Import-Module -Name $logicModulePath -Force
Import-Module -Name $toolsModulePath -Force

# --- Main Logic ---
Write-Host "Scanning file structure..." -ForegroundColor Cyan
$allFiles = Get-ChildItem -Path $Root -Recurse -File -Exclude ".git" -ErrorAction SilentlyContinue | ForEach-Object {
    [pscustomobject]@{
        Path = $_.FullName
        RelativePath = Get-JanusRelativePath -Path $_.FullName -Root $Root
        SizeBytes = $_.Length
        LastWriteUtc = $_.LastWriteTimeUtc
    }
}
$allFiles | Export-Csv -Path $listingCsv -NoTypeInformation -Encoding UTF8

Write-Host "Analyzing changes..." -ForegroundColor Cyan
$changes = @{ Added = @(); Removed = @() }
if (Test-Path $prevListingCsv) {
    # --- CORRECTED SECTION: Handle empty previous CSV file ---
    $importedPrevCsv = Import-Csv $prevListingCsv
    $prevFiles = if ($importedPrevCsv) { $importedPrevCsv.RelativePath } else { @() }
    # --- End of corrected section ---
    
    $currFiles = $allFiles.RelativePath
    $changes.Removed = Compare-Object -ReferenceObject $prevFiles -DifferenceObject $currFiles -PassThru | Where-Object { $_.SideIndicator -eq '<=' }
    $changes.Added = Compare-Object -ReferenceObject $prevFiles -DifferenceObject $currFiles -PassThru | Where-Object { $_.SideIndicator -eq '=>' }
}

Write-Host "Assembling the Brain Map..." -ForegroundColor Cyan
$sb = [System.Text.StringBuilder]::new()
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
$sb.AppendLine("===== Janus Brain Map — $stamp =====") | Out-Null
$sb.AppendLine("Total Files Indexed: $($allFiles.Count)") | Out-Null
$sb.AppendLine("="*80) | Out-Null
$sb.AppendLine("") | Out-Null

$sb.AppendLine("--- RECENT CHANGES ---") | Out-Null
if ($changes.Added.Count -gt 0) {
    $sb.AppendLine("ADDED:") | Out-Null
    $changes.Added | ForEach-Object { $sb.AppendLine("  + $_") } | Out-Null
}
if ($changes.Removed.Count -gt 0) {
    $sb.AppendLine("REMOVED:") | Out-Null
    $changes.Removed | ForEach-Object { $sb.AppendLine("  - $_") } | Out-Null
}
if ($changes.Added.Count -eq 0 -and $changes.Removed.Count -eq 0) {
    $sb.AppendLine("No structural changes since last scan.") | Out-Null
}
$sb.AppendLine("") | Out-Null

$sb.AppendLine("--- FULL INVENTORY (Path, Size) ---") | Out-Null
$allFiles | Sort-Object RelativePath | ForEach-Object {
    $sizeFormatted = if ($_.SizeBytes -ge 1MB) {
        "{0:N2} MB" -f ($_.SizeBytes / 1MB)
    } elseif ($_.SizeBytes -ge 1KB) {
        "{0:N2} KB" -f ($_.SizeBytes / 1KB)
    } else {
        "$($_.SizeBytes) B"
    }
    $line = "{0,-70} {1,10}" -f $_.RelativePath, $sizeFormatted
    $sb.AppendLine($line) | Out-Null
}

$sb.ToString() | Set-Content -Path $mapFile -Encoding UTF8
Copy-Item -Path $listingCsv -Destination $prevListingCsv -Force
Write-Host "✔ Brain Map updated successfully: '$mapFile'" -ForegroundColor Green