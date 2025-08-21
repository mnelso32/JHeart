#requires -Version 7.0
# This script sends a prompt to the local LLM server running in LM Studio.

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Prompt,

    [string]$ApiUri = "http://localhost:1234/v1/chat/completions"
)

# --- Main Logic ---
$headers = @{
    "Content-Type" = "application/json"
}

$body = @{
    model = "local-model" # This is a placeholder, LM Studio uses the loaded model
    messages = @(
        @{
            role = "system"
            content = "You are Janus, a helpful AI assistant." # A minimal system prompt
        },
        @{
            role = "user"
            content = $Prompt
        }
    )
    temperature = 0.7
} | ConvertTo-Json -Depth 5

try {
    Write-Host "Sending prompt to local LLM..." -ForegroundColor Gray
    $response = Invoke-RestMethod -Uri $ApiUri -Method Post -Headers $headers -Body $body
    $aiResponse = $response.choices[0].message.content
    
    Write-Host "--- Janus Response ---" -ForegroundColor Cyan
    Write-Host $aiResponse
    Write-Host "--------------------" -ForegroundColor Cyan
}
catch {
    Write-Warning "Failed to send prompt to LLM. Is the LM Studio server running?"
    Write-Warning $_.Exception.Message
}