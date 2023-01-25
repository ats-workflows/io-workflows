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

<#
## Verify/validate Polaris scan
## Requires: Polaris scna logs (IO logs), Project Languages
## Returns: N/A
#>
Function Polaris_Validate() {
  Param($IOLog, $ProjectLanguage)
  
  $IsNewOnboarding = $true
  $ValidationFailure = $false
  $EmittedLanguages = @()
  
  $OnboardArray = Get-Content $IOLog | Select-String -Pattern "Project created in Portal"
  if ($OnboardArray.Length -eq 0) {
    $IsNewOnboarding = $false
  }
  
  $EmittedContentArray = Get-Content $IOLog | Select-String -Pattern "Emitted"
  ForEach ($EmittedContent in $EmittedContentArray) {
    $ContentArray = -Split $EmittedContent
    
    $EmittedIndex = $ContentArray.IndexOf('Emitted')
    $CompilationIndex = $ContentArray.IndexOf('compilation')
    
    $EmittedIndex += 2
    $CompilationIndex -= 1
    
    $EmittedLanguage = $ContentArray[$EmittedIndex..$CompilationIndex] | Out-String
    $EmittedLanguage = $EmittedLanguage.Replace("`r", "")
    $EmittedLanguage = $EmittedLanguage.Replace("`n", " ")
    $EmittedLanguage = $EmittedLanguage.Trim()
    $EmittedLanguages += $EmittedLanguage

    $EmissionPercentage = $ContentArray[$ContentArray.Length-2] | Out-String
    $EmissionPercentage = $EmissionPercentage.Replace("`n", "")
    $EmissionPercentage = $EmissionPercentage.Trim()
    
    if ($EmissionPercentage -Like "*100*") { 
      Write-Host "Language - $EmittedLanguage - Emitted: $EmissionPercentage"
    } else {
      Write-Error "Language - $EmittedLanguage - did not emit 100% ( $EmissionPercentage )"
      $ValidationFailure = $true
    }
  }
  
  $ProjectLanguageArray = $ProjectLanguage.Split(",")
  ForEach($ProjLang in $ProjectLanguageArray) {
    if ($EmittedLanguages -NotContains $ProjLang.Trim()) {
      Write-Error "Language - $ProjLang not detected by Polaris."
      $ValidationFailure = $true
    }
  }
  
  if ($ValidationFailure) {
    Write-Error "Polaris onboarding failure"
    Exit 1
  } 
  
  if ($IsNewOnboarding) {
    Write-Host "Polaris onboarding successful - scan validation complete."
  } else {
    Write-Host "Polaris project already onboarded - scan validation complete."
  }
}
