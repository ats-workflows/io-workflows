<#
## Code Dx
#>

<#
## Code Dx Health Check
## Requires: Code Dx Server URL
## Returns: N/A
#>
Function Dx_HealthCheck() {
  Param($CodeDxURL)

  try {
    Write-Host "=========="

    $CodeDx_Response = Invoke-RestMethod -URI $CodeDxURL/x/system-status -Method 'GET'
    Write-Host "Code Dx Ready Status: $($CodeDx_Response.isReady)"
    Write-Host "Code Dx Alive Status: $($CodeDx_Response.isAlive)"
    Write-Host "Code Dx State: $($CodeDx_Response.state)"

    Write-Host "=========="
  } catch {
    Write-Error "Failed Code Dx Health Check"
  }
}

<#
## Query projects on Code Dx filtering by the provided name
## Requires: Code Dx Server URL, Access Token, Project Id
## Returns: Code Dx projects API response
#>
Function Dx_GetProjects() {
  Param($CodeDxURL, $CodeDxToken, $ProjectName)

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "*/*")
  $Headers.Add("Content-Type", "*/*")
  $Headers.Add("Authorization", "Bearer $CodeDxToken")
  $Body = @"
{ "filter": {"name": "$ProjectName"} }
"@
  $Response = Invoke-RestMethod "$CodeDxURL/api/projects/query" -Method 'POST' -Headers $Headers -Body $Body

  return $Response
}

<#
## Returns the Id of the Code Dx project matching the provided project name
## Requires: Code Dx Project Query API Response, Project Name
## Returns: Code Dx project if found, -1 otherwise
#>
Function Dx_GetProjectIdFromResponse() {
  Param($DxProjectResponse, $ProjectName)

  $DxProjectId = -1
  if ($DxProjectResponse.count -gt 0) {
    ForEach ($Project in $DxProjectResponse) {
      if ($ProjectName -eq $($Project.name)) {
        $DxProjectId = $($Project.id)
      }
    }

    if ($DxProjectId -gt 0) {
      Write-Host "Code Dx project Id: $DxProjectId"
    } else {
      Write-Host "No project found on Code Dx matching the name: $ProjectName"
    }
  } else {
    Write-Host "No projects returned from Code Dx with the query filter for project name: $ProjectName"
  }

  return $DxProjectId
}

<#
## Get the list of Tool Connectors for the provided project from Code Dx
## Requires: Code Dx Server URL, Access Token, Project Id
## Returns: Code Dx project's Tool Connectors
#>
Function Dx_GetProjectToolConnectors() {
  Param($CodeDxURL, $CodeDxToken, $DxProjectId)

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "application/json")
  $Headers.Add("Authorization", "Bearer $CodeDxToken")
  $Response = Invoke-RestMethod "$CodeDxURL/api/tool-connector-config/entries/$DxProjectId" -Method 'GET' -Headers $Headers

  return $Response
}

<#
## Create an empty (unconfigured) Polaris Tool Connector on Code Dx for the provided branch
## Requires: Code Dx Server URL, Access Token, Project Id, Branch Name
## Returns: Code Dx project's new Polaris Tool Connector's Id
#>
Function Dx_CreateEmptyPolarisToolConnector() {
  Param($CodeDxURL, $CodeDxToken, $DxProjectId, $BranchName)

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "application/json")
  $Headers.Add("Content-Type", "*/*")
  $Headers.Add("Authorization", "Bearer $CodeDxToken")
  $Body = @"
{ "tool": "Polaris","name": "Polaris Connector ($BranchName)" }
"@
  $Response = Invoke-RestMethod "$CodeDxURL/api/tool-connector-config/entries/$DxProjectId" -Method 'POST' -Headers $Headers -Body $Body

  return $Response.id
}

<#
## Update the Polaris Tool Connector configuration (enabled to run during normal analysis + branch-sync option checked) for the provided project
## Requires:
##  Code Dx: Server URL, Access Token, Project Id, Connector Id, Branch Name
##  Polaris: Server URL, Access Token, Project Id, Branch Id
## Returns: N/A
#>
Function Dx_UpdatePolarisToolConnector() {
  Param($CodeDxURL, $CodeDxToken, $DxProjectId, $DxConnectorId, $BranchName, $PolarisURL, $PolarisToken, $PolarisProjectId, $PolarisBranchId)

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "application/json")
  $Headers.Add("Content-Type", "*/*")
  $Headers.Add("Authorization", "Bearer $CodeDxToken")
  $Body = @"
{
  "server_url": "$PolarisURL",
  "api_token": "$PolarisToken",
  "connector_mode": "project",
  "auto-refresh-interval": false,
  "available-during-analysis": true,
  "project": "$PolarisProjectId",
  "branch": { "value": "$PolarisBranchId", "syncWith": "$BranchName" }
}
"@
  Invoke-RestMethod "$CodeDxURL/api/tool-connector-config/values/$DxConnectorId" -Method 'PUT' -Headers $Headers -Body $Body
}

<#
## Get the branches for the provided project from Code Dx
## Requires: Code Dx: Server URL, Access Token, Project Id
## Returns: Code Dx branch API response
#>
Function Dx_GetProjectBranches() {
  Param($CodeDxURL, $CodeDxToken, $DxProjectId)

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "application/json")
  $Headers.Add("Authorization", "Bearer $CodeDxToken")
  $Response = Invoke-RestMethod "$CodeDxURL/x/projects/$DxProjectId/branches" -Method 'GET' -Headers $Headers

  return $Response
}

<#
## Run Code Dx analysis on the provided branch
## Requires: Code Dx: Server URL, Access Token, Project Id, Branch Name
## Returns: Code Dx analysis API response
#>
Function Dx_RunAnalysisOnBranch() {
  Param($CodeDxURL, $CodeDxToken, $DxProjectId, $BranchName)

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "*/*")
  $Headers.Add("Content-Type", "multipart/form-data")
  $Headers.Add("Authorization", "Bearer $CodeDxToken")
  $Form = @{
    filenames        = ''
    includeGitSource = ''
    gitBranchName    = ''
    BranchName       = "$BranchName"
  }
  $Response = Invoke-RestMethod "$CodeDxURL/api/projects/$DxProjectId/analysis" -Method 'POST' -Headers $Headers -Form $Form

  return $Response
}

<#
## Create an analysis "prep" on Code Dx
## Requires: Code Dx Server URL, Access Token, Project Id
## Returns: Code Dx Analysis Prep API Response
#>
Function Dx_CreateAnalysisPrep() {
  Param($CodeDxURL, $CodeDxToken, $CodeDxProjectId)

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "application/json")
  $Headers.Add("Content-Type", "application/json")
  $Headers.Add("Authorization", "Bearer $CodeDxToken")
  $Body = @"
{ "projectId": "$CodeDxProjectId" }
"@
  $Response = Invoke-RestMethod "$CodeDxURL/api/analysis-prep" -Method 'POST' -Headers $Headers -Body $Body

  return $Response
}

<#
## Query Code Dx for the state of a running job
## Requires: Code Dx Server URL, Access Token, Job Id
## Returns: Status of the Code Dx job.
#>
Function Dx_QueryJobState() {
  Param($CodeDxURL, $CodeDxToken, $JobId)

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "application/json")
  $Headers.Add("Authorization", "Bearer $CodeDxToken")

  $Response = Invoke-RestMethod "$CodeDxURL/api/jobs/$JobId" -Method 'GET' -Headers $Headers
  $JobStatus = $Response.status

  Write-Host "Job Status: $JobStatus"
  return $JobStatus
}

<#
## Query Code Dx for the state of analysis-prep
## Requires: Code Dx Server URL, Access Token, Analysis Prep Id
## Returns: Code Dx Analysis Prep API Response.
#>
Function Dx_QueryAnalysisPrep() {
  Param($CodeDxURL, $CodeDxToken, $DxAnalysisPrepId)

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "application/json")
  $Headers.Add("Authorization", "Bearer $CodeDxToken")
  $Response = Invoke-RestMethod "$CodeDxURL/api/analysis-prep/$DxAnalysisPrepId" -Method 'GET' -Headers $Headers

  return $Response
}

<#
## Update analysis prep on Code Dx to target a specific branch
## Requires: Code Dx Server URL, Access Token, Analysis Prep Id, Branch Name
## Returns: N/A
#>
Function Dx_UpdateAnalysisPrep() {
  Param($CodeDxURL, $CodeDxToken, $DxAnalysisPrepId, $CodeDxBranchName)

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "*/*")
  $Headers.Add("Content-Type", "application/json")
  $Headers.Add("Authorization", "Bearer $CodeDxToken")
  $Body = @"
{ "branch": "$CodeDxBranchName" }
"@
  Invoke-RestMethod "$CodeDxURL/x/analysis-prep/$DxAnalysisPrepId/branch" -Method 'PUT' -Headers $Headers -Body $Body
}

<#
## Begin analysis on Code Dx for the provided branch.
## This auto-runs all configured Tool Connectors that have the "Run this connector during normal analysis" option checked
## Requires: Code Dx Server URL, Access Token, Analysis Prep Id, Code Dx Branch Name
## Returns: N/A.
#>
Function Dx_Analyze() {
  Param($CodeDxURL, $CodeDxToken, $DxAnalysisPrepId, $CodeDxBranchName)

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "*/*")
  $Headers.Add("Authorization", "Bearer $CodeDxToken")
  $Body = @"
{ "branch": "$CodeDxBranchName" }
"@
  Invoke-RestMethod "$CodeDxURL/x/analysis-prep/$DxAnalysisPrepId/analyze" -Method 'POST' -Headers $Headers -Body $Body
}
