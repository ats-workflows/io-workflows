<#
## Polaris
#>

<#
## Authenticate with Polaris to get a JWT token for use on API calls
## Requires: Polaris Server URL, Polaris Personal Acces Token
## Returns: Polaris JWT
#>
Function Polaris_Authenticate() {
  Param($PolarisURL, $PolarisToken)

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "application/json")
  $Headers.Add("Content-Type", "application/x-www-form-urlencoded")
  $Body = "accesstoken=$PolarisToken"
  $Response = Invoke-RestMethod "$PolarisURL/api/auth/v0/authenticate" -Method 'POST' -Headers $Headers -Body $Body

  return $Response.jwt
}

<#
## Polaris Status/Healtchcheck
## Requires: Polaris Server URL, Polaris JWT
## Returns: N/A
#>
Function Polaris_HealthCheck() {
  Param($PolarisURL, $PolarisJWT)

  try {
    Write-Host "=========="

    $PolarisStatusURL = $PolarisURL.replace('polaris', 'status.polaris')
  
    $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $Headers.Add("Accept", "*/*")
    $Headers.Add("Authorization", "Bearer $PolarisJWT")
    $PolarisStatusResponse = Invoke-RestMethod "$PolarisStatusURL/api/v2/status.json" -Method 'GET' -Headers $Headers
    Write-Host "Polaris Status: $($PolarisStatusResponse.status.description) (Indicator: $($PolarisStatusResponse.status.indicator), updated on: $($PolarisStatusResponse.page.updated_at))"
    
    Write-Host "=========="
  } catch {
    Write-Error "Failed Polaris Health Check"
  }    
}

<#
## Get Polaris project(s) filtered by the provided project name
## Requires: Polaris Server URL, Polaris JWT, Polaris project name
## Returns: Polaris project API response
#>
Function Polaris_GetProjectByName() {
  Param($PolarisURL, $PolarisJWT, $ProjectName)

  $PolarisProjectQueryLimit = 1

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "application/vnd.api+json")
  $Headers.Add("Authorization", "Bearer $PolarisJWT")
  $Response = Invoke-RestMethod "$PolarisURL/api/common/v0/projects?page[limit]=$PolarisProjectQueryLimit&filter[project][name][eq]=$ProjectName" -Method 'GET' -Headers $Headers

  return $Response
}

<#
## Get Polaris branches for the provided project Id
## Requires: Polaris Server URL, Polaris JWT, Polaris project Id
## Returns: Array of Polaris project's branches
#>
Function Polaris_GetProjectBranches() {
  Param($PolarisURL, $PolarisJWT, $PolarisProjectId)

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "application/vnd.api+json")
  $Headers.Add("Authorization", "Bearer $PolarisJWT")
  Invoke-RestMethod "$PolarisURL/api/common/v0/projects/$PolarisProjectId/related/branches?page[limit]=100" -Method 'GET' -Headers $Headers

  return $Response
}
