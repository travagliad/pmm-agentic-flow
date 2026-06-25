# Full test flow: Refinement -> In Progress -> In QA (secrets from terraform.tfvars).
# Usage: .\scripts\run-pmm-15167-flow.ps1
$ErrorActionPreference = 'Stop'

$steps = @(
    @{ Status = 'Ready for Refinement'; Summary = '[RTA] Real-Time Query Analytics for PostgreSQL' },
    @{ Status = 'In Progress'; Summary = '[RTA] Real-Time Query Analytics for PostgreSQL' },
    @{ Status = 'In QA'; Summary = '[RTA] Real-Time Query Analytics for PostgreSQL' }
)

foreach ($step in $steps) {
    Write-Host "`n######## $($step.Status) ########`n" -ForegroundColor Cyan
    & "$PSScriptRoot\simulate-pmm-15167.ps1" -Status $step.Status -Summary $step.Summary
    if ($step.Status -ne 'In QA') {
        Write-Host "Waiting 15s before next step..."
        Start-Sleep -Seconds 15
    } else {
        Write-Host "Waiting 90s for QA runner provision..."
        Start-Sleep -Seconds 90
    }
}

Write-Host "`n==> Final ticket state`n" -ForegroundColor Green
& "$PSScriptRoot\test-stack.ps1"
