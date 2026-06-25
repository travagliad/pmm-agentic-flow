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

curl.exe -sS -X POST "$base/hooks/jira" `
    -H "Content-Type: application/json" `
    -H "x-webhook-secret: $secret" `
    -H "ngrok-skip-browser-warning: true" `
    --data-binary $body

Write-Host ""
Write-Host ""
Write-Host "==> Ticket state"
Start-Sleep -Seconds 2
curl.exe -sS -H "x-api-key: $secret" -H "ngrok-skip-browser-warning: true" "$base/orchestrator/tickets/$Ticket"
Write-Host ""
Write-Host ""
Write-Host "==> Chat link"
Write-Host "$base/tickets/$Ticket/chat"
