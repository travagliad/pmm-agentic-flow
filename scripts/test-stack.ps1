# Smoke test control plane after terraform apply.
# Usage: .\scripts\test-stack.ps1
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\load-tfvars.ps1" | Out-Null
$tf = & "$PSScriptRoot\load-tfvars.ps1"

$base = $tf.NgrokDomain
$secret = $tf.ApiSecret
$headers = @{ 'ngrok-skip-browser-warning' = 'true' }

Write-Host "==> Base URL: $base"
Write-Host ""

Write-Host "==> Orchestrator health"
curl.exe -sS -H "ngrok-skip-browser-warning: true" "$base/orchestrator/health"
Write-Host ""
Write-Host ""

Write-Host "==> Canvas (root)"
curl.exe -sS -o NUL -w "HTTP %{http_code}`n" -H "ngrok-skip-browser-warning: true" "$base/"
Write-Host ""

Write-Host "==> Ticket PMM-15167"
curl.exe -sS -H "x-api-key: $secret" -H "ngrok-skip-browser-warning: true" "$base/orchestrator/tickets/PMM-15167"
Write-Host ""
