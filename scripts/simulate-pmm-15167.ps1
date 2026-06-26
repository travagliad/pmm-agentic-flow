# Simulate Jira webhook transitions for PMM-15167 (secrets from terraform.tfvars).
# Usage:
#   .\scripts\simulate-pmm-15167.ps1                    # In Progress (default)
#   .\scripts\simulate-pmm-15167.ps1 -Status "In QA"
#   .\scripts\simulate-pmm-15167.ps1 -Status "Ready for Refinement"
param(
    [string]$Ticket = 'PMM-15167',
    [string]$Status = 'In Progress',
    [string]$Summary = '[RTA] Real-Time Query Analytics for PostgreSQL'
)

$ErrorActionPreference = 'Stop'
$tf = & "$PSScriptRoot\load-tfvars.ps1"

$base = $tf.NgrokDomain
$secret = $tf.ApiSecret

$body = @{
    issue = @{
        key    = $Ticket
        fields = @{
            summary = $Summary
            status  = @{ name = $Status }
        }
    }
} | ConvertTo-Json -Depth 5 -Compress

Write-Host "==> POST $base/hooks/jira"
Write-Host "    Ticket: $Ticket  Status: $Status"
Write-Host ""

$response = curl.exe -sS -w "`n%{http_code}" -X POST "$base/hooks/jira" `
    -H "Content-Type: application/json" `
    -H "x-webhook-secret: $secret" `
    -H "ngrok-skip-browser-warning: true" `
    --data-binary $body

$lines = $response -split "`n"
$httpCode = $lines[-1]
$bodyOut = ($lines[0..($lines.Length - 2)] -join "`n").Trim()
Write-Host $bodyOut
if ($httpCode -eq '202') {
    Write-Host "`n(202 Accepted — orchestrator processing in background; poll ticket state below)"
} elseif ($httpCode -ge '400') {
    Write-Host "`nHTTP $httpCode" -ForegroundColor Red
}

Write-Host ""
Write-Host "==> Ticket state (wait a few seconds if transition just started)"
Start-Sleep -Seconds 5
curl.exe -sS -H "x-api-key: $secret" -H "ngrok-skip-browser-warning: true" "$base/orchestrator/tickets/$Ticket"
Write-Host ""
Write-Host ""
Write-Host "==> Chat link"
Write-Host "$base/tickets/$Ticket/chat"
