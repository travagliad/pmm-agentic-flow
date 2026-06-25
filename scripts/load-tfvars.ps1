# Parse terraform/terraform.tfvars (simple key = "value" lines).
param(
    [string]$TfvarsPath = (Join-Path (Split-Path $PSScriptRoot -Parent) "terraform\terraform.tfvars")
)

if (-not (Test-Path $TfvarsPath)) {
    throw "terraform.tfvars not found: $TfvarsPath"
}

$vars = @{}
Get-Content $TfvarsPath | ForEach-Object {
    if ($_ -match '^\s*([a-z_][a-z0-9_]*)\s*=\s*"(.*)"\s*$') {
        $vars[$Matches[1]] = $Matches[2]
    }
}

return [pscustomobject]@{
    ApiSecret          = $vars['api_secret']
    AgentCanvasApiKey  = $vars['agent_canvas_api_key']
    NgrokDomain        = ($vars['ngrok_domain'] -replace '/$', '')
    JiraBaseUrl        = $vars['jira_base_url']
    JiraEmail          = $vars['jira_email']
    JiraApiToken       = $vars['jira_api_token']
    CursorApiKey       = $vars['cursor_api_key']
    LinodeToken        = $vars['linode_token']
}
