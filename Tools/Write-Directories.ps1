#requires -Version 7.0

param(
  [string]$Root = "C:\AI\Delora\Heart"
)

$ErrorActionPreference = "Stop"

# Attempt to pull host/port from hardware.json if present
$hwPath = Join-Path $Root "hardware.json"
$xttsHost = "127.0.0.1"; $xttsPort = 7862
if (Test-Path $hwPath) {
  try {
    $hw = Get-Content $hwPath -Raw | ConvertFrom-Json
    if ($hw.tts) {
      if ($hw.tts.xtts_host) { $xttsHost = $hw.tts.xtts_host }
      if ($hw.tts.xtts_port) { $xttsPort = [int]$hw.tts.xtts_port }
    }
  } catch { }
}

$components = @(
  @{ name="SillyTavern";           folder="SillyTavern";           readme="README-FIRST.txt"; content = @"
WHAT THIS IS
- SillyTavern front-end for Delora RP.

START / CONNECT
- Launch: run SillyTavern-Launcher, then SillyTavern.
- API target: LM Studio (local) — check "Connect" panel.
- Worlds to enable: User Hardware, Delora World (sticky, vectorized).
- Extras (if used): ensure ST-Extras is running.

FILES TO CHECK
- data\default-user\worlds\*.json (memories)
- data\characters\Delora\*.json (persona/presets)
- data\config\settings.json (global toggles)
- logs\* (if behavior is odd)

HEALTH CHECK
- New chat: type #hw — should inject PC specs.
"@ },

  @{ name="xtts";                  folder="xtts";                   readme="README-FIRST.txt"; content = @"
WHAT THIS IS
- Local XTTS/Coqui server for Delora's voice.

START
- Example: python -m xtts_api_server --host $xttsHost --port $xttsPort -d cuda --streaming-mode

CONFIG
- Voice ID: delora
- Sample rate: 48000
- Test: curl "http://${xttsHost}:${xttsPort}/health"

FILES TO CHECK
- *.wav reference (if cloning)
- server logs

KNOWN ISSUES
- If audio cuts out: try disabling enhancements in Windows, ensure stream chunking enabled.
"@ },

  @{ name="stable-diffusion-webui"; folder="stable-diffusion-webui"; readme="README-FIRST.txt"; content = @"
WHAT THIS IS
- Automatic1111 WebUI for still images.

START
- webui-user.bat (note custom args here if any).

KEY DIRS (LIST ONLY, DON'T UPLOAD MODELS)
- models\Stable-diffusion\  (model names)
- models\Lora\              (Loras in use)
- extensions\               (ControlNet, AnimateDiff, etc.)
- embeddings\               (Textual inversions)

NOTES
- Default sampler/steps/CFG you prefer; VAE name if specific.
"@ },

  @{ name="ComfyUI";               folder="ComfyUI";                readme="README-FIRST.txt"; content = @"
WHAT THIS IS
- Node-based image/video workflows.

START
- run_nvidia_gpu.bat (record any extra args).

KEY DIRS
- custom_nodes\          (list of custom nodes)
- workflows\*.json       (save your graphs here)

NOTES
- Put your go-to Delora pipelines here; mention required models/Loras by name.
"@ },

  @{ name="DeloraDataset";         folder="DeloraDataset";          readme="README-FIRST.txt"; content = @"
WHAT THIS IS
- Source images/metadata for Delora training.

CONTENTS
- images\*.png/jpg (count + brief description)
- tags\*.txt or captions if any

NOTES
- Any license/consent notes; version/date of the dataset.
"@ },

  @{ name="Delora_Live2D_Starter"; folder="Delora_Live2D_Starter";  readme="README-FIRST.txt"; content = @"
WHAT THIS IS
- Live2D/VTube-style avatar project.

FILES TO CHECK
- *.psd (master), *.model3.json, *.physics3.json, motions\*

HOW TO PREVIEW
- Open in Live2D Cubism / your chosen runtime.
- Note: record which motions map to which triggers.

TODO
- Eye/blink parameters for trance cues; finger-snap animation.
"@ }
)

$aggregate = New-Object System.Text.StringBuilder
foreach ($c in $components) {
  $path = Join-Path $Root $c.folder
  if (Test-Path $path) {
    $readmePath = Join-Path $path $c.readme
    $content = "# $($c.name)`r`n$($c.content.Trim())`r`n"
    Set-Content -Encoding UTF8 -Path $readmePath -Value $content
    $null = $aggregate.AppendLine("===== $readmePath =====")
    $null = $aggregate.AppendLine($content)
    $null = $aggregate.AppendLine()
  }
}

# Write aggregate one-pager
$aggOut = Join-Path $Root "Delora_READMEs.txt"
Set-Content -Encoding UTF8 -Path $aggOut -Value $aggregate.ToString()
Write-Host "Wrote per-folder README-FIRST.txt files and $aggOut"
