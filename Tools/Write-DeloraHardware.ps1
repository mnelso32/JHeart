


# Creates/updates: C:\AI\Delora\hardware.json
# Creates/updates: SillyTavern World Info "User Hardware.json"

$ErrorActionPreference = "Stop"

# --- Paths ---
$root = "C:\AI\Delora\Heart"
$tools = Join-Path $root "tools"
$hardwareJson = Join-Path $root "hardware.json"

# Adjust this if your ST path differs:
$stWorlds = Join-Path $env:USERPROFILE "SillyTavern-Launcher\SillyTavern\data\default-user\worlds"
$userWorldJson = Join-Path $stWorlds "User Hardware.json"

# --- Gather system info ---
$cpu  = Get-CimInstance Win32_Processor | Select-Object -First 1 Name, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed
$gpus = Get-CimInstance Win32_VideoController | Select-Object Name, AdapterRAM, DriverVersion
$ramModules = Get-CimInstance Win32_PhysicalMemory | Select-Object Manufacturer, PartNumber, ConfiguredClockSpeed, Speed, Capacity
$board = Get-CimInstance Win32_BaseBoard | Select-Object Manufacturer, Product
$os    = Get-CimInstance Win32_OperatingSystem | Select-Object Caption, Version, OSArchitecture, BuildNumber
$disks = Get-CimInstance Win32_DiskDrive | Select-Object Model, Size, InterfaceType, MediaType
$audio = Get-CimInstance Win32_SoundDevice | Select-Object Name, Manufacturer

$totalRamGB = [math]::Round(($ramModules | Measure-Object -Property Capacity -Sum).Sum / 1GB)
$ramSpeed = ($ramModules | Where-Object {$_.ConfiguredClockSpeed -gt 0} | Select-Object -Expand ConfiguredClockSpeed -First 1)
if (-not $ramSpeed) { $ramSpeed = ($ramModules | Select-Object -Expand Speed -First 1) }

$gpuArr = @()
foreach ($g in $gpus) {
  $gpuArr += [ordered]@{
    model   = $g.Name
    vram_gb = [int]([math]::Round(($g.AdapterRAM) / 1GB))
    driver  = $g.DriverVersion
  }
}

$ramMods = @()
foreach ($m in $ramModules) {
  $ramMods += [ordered]@{
    size_gb     = [int]([math]::Round($m.Capacity / 1GB))
    speed_mt_s  = [int]$ramSpeed
    voltage_v   = 0.0   # fill manually if you want
    part        = ($m.PartNumber -replace '\s+$','')
  }
}

$diskArr = @()
foreach ($d in $disks) {
  $diskArr += [ordered]@{
    model   = $d.Model
    size_gb = [int]([math]::Round($d.Size / 1GB))
    type    = ($d.InterfaceType -replace '\s+','')
  }
}

$audioName = ($audio | Select-Object -Expand Name | Select-Object -First 1)

# --- Build hardware.json object ---
$hw = [ordered]@{
  updated_at = (Get-Date).ToString("yyyy-MM-dd")
  os = @{
    name = $os.Caption
    build = $os.BuildNumber
    arch = $os.OSArchitecture
  }
  cpu = @{
    model = $cpu.Name
    cores = $cpu.NumberOfCores
    threads = $cpu.NumberOfLogicalProcessors
    max_clock_mhz = $cpu.MaxClockSpeed
  }
  gpu = $gpuArr
  ram = @{
    total_gb = $totalRamGB
    ddr_gen = "DDR5"
    xmp_expo_enabled = $true
    speed_mt_s = [int]$ramSpeed
    modules = $ramMods
  }
  motherboard = @{
    manufacturer = $board.Manufacturer
    model = $board.Product
    bios_version = ""
  }
  storage = $diskArr
  audio = @{
    device = $audioName
    sample_rate_hz = 48000
  }
  tts = @{
    xtts_host = "127.0.0.1"
    xtts_port = 7862
    voice_id  = "delora"
  }
  llm = @{
    runner = "LM Studio"
    primary_model = ""
    quant = ""
    context_len = 0
  }
}

# Ensure folders
New-Item -ItemType Directory -Force -Path $root, $tools | Out-Null
New-Item -ItemType Directory -Force -Path $stWorlds | Out-Null

# Write hardware.json
($hw | ConvertTo-Json -Depth 6) | Set-Content -Encoding UTF8 $hardwareJson
Write-Host "Wrote $hardwareJson"

# --- Create a compact World Info entry for SillyTavern ---
$gpuLine = ($gpuArr | ForEach-Object { "$($_.model) $($_.vram_gb)GB" }) -join "; "
$diskLine = ($diskArr | ForEach-Object { "$($_.model) $($_.size_gb)GB" }) -join "; "

$content = @"
PC Specs (updated $($hw.updated_at)):
CPU: $($hw.cpu.model) ($($hw.cpu.cores)c/$($hw.cpu.threads)t, ~$($hw.cpu.max_clock_mhz) MHz)
GPU: $gpuLine
RAM: $($hw.ram.total_gb) GB $($hw.ram.ddr_gen) @$($hw.ram.speed_mt_s) MT/s
Mobo: $($hw.motherboard.manufacturer) $($hw.motherboard.model)
Storage: $diskLine
OS: $($hw.os.name) (build $($hw.os.build)), $($hw.os.arch)
TTS: XTTS at $($hw.tts.xtts_host):$($hw.tts.xtts_port) voice=$($hw.tts.voice_id)
LLM: $($hw.llm.runner) model=$($hw.llm.primary_model) quant=$($hw.llm.quant)
"@.Trim()

$wi = @{
  entries = @{
    "0" = @{
      uid = 0
      key = @("hardware","#hw","specs","ram","vram","gpu","cpu","motherboard","storage","xtts","lm studio")
      keysecondary = @()
      comment = "User hardware baseline"
      content = $content
      constant = $false
      vectorized = $true
      selective = $true
      order = 10
      position = 0      # 0=before; 1=after (ST uses 0 for pre, matches your existing world)
      disable = $false
      sticky = 1        # always inject
      groupOverride = $false
      groupWeight = 100
      triggers = @()
    }
  }
}

($wi | ConvertTo-Json -Depth 6) | Set-Content -Encoding UTF8 $userWorldJson
Write-Host "Wrote $userWorldJson"
