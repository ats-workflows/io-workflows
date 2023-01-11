<#
## Intelligent Orchestration
#>

$ValidProjectLanguages = @{}
$ValidProjectLanguages.Add("JAVA", @("OTHER", "NOT_SPECIFIED"))
$ValidProjectLanguages.Add("JAVASCRIPT", @("OTHER", "NOT_SPECIFIED"))
$ValidProjectLanguages.Add("C++", @("OTHER", "NOT_SPECIFIED"))
$ValidProjectLanguages.Add("C#", @("OTHER", "NOT_SPECIFIED"))
$ValidProjectLanguages.Add("GO", @("OTHER", "NOT_SPECIFIED"))
$ValidProjectLanguages.Add("RUBY", @("OTHER", "NOT_SPECIFIED"))
$ValidProjectLanguages.Add("PYTHON", @("OTHER", "NOT_SPECIFIED"))
$ValidProjectLanguages.Add("SWIFT", @("OTHER", "NOT_SPECIFIED"))
$ValidProjectLanguages.Add("PHP", @("OTHER", "NOT_SPECIFIED"))
$ValidProjectLanguages.Add("PERL", @("OTHER", "NOT_SPECIFIED"))
$ValidProjectLanguages.Add("OTHER", @("Other", "NOT_SPECIFIED"))

<#
## Normalize IO URL (trim down to base URL & remove trailing slash; if applicable)
## Requires: IO Server URL
## Returns: IO Server Base URL
#>
Function IO_NormalizeURL() {
  Param($IOURL)

  # Check if the provided URL contains an "api" path
  if ($IOURL -like "*api*") {
    Write-Verbose "Trimming URL to base URL"
    $Index_API = $IOURL.IndexOf('api')
    $IOURL = $IOURL.Substring(0, $Index_API)
  }

  # Remove trailing forward salsh, if applicable
  if ($IOURL.EndsWith('/')) {
    Write-Verbose "Trimming trailing forward slash from URL: $IOURL"
    $IOURL = $IOURL.Substring(0, $IOURL.Length-1)
  }

  return $IOURL
}

<#
## Intelligent Orchestration Health Check
## Requires: IO Server URL
## Returns: N/A
#>
Function IO_HealthCheck() {
  Param($IOURL)
  
  try {
    Write-Host "=========="
    
    $IO_IQ_Response = Invoke-RestMethod -URI $IOURL/api/ioiq/actuator/health -Method 'GET'
    Write-Host "IO IQ Status: $($IO_IQ_Response.status)"
    Write-Host "IO IQ DataBase Status: $($IO_IQ_Response.components.db.status)"
    Write-Host "IO IQ Disk Space Status: $($IO_IQ_Response.components.diskSpace.status)"
    Write-Host "IO IQ Liveliness Status: $($IO_IQ_Response.components.livenessState.status)"
    Write-Host "IO IQ Ping Status: $($IO_IQ_Response.components.ping.status)"
    Write-Host "IO IQ Readiness Status: $($IO_IQ_Response.components.readinessState.status)"

    $IO_WF_Response = Invoke-RestMethod -URI $IOURL/api/workflowengine/actuator/health -Method 'GET'
    Write-Host "IO Workflow Engine Status: $($IO_WF_Response.status)"
    
    Write-Host "=========="
  } catch {
    Write-Error "Failed Intelligent Orchestration Health Check"
  }
}

<#
## Query IO for Project by Name
## Requires: IO Server URL, Access Token, Project Name
## Returns: IO Project, if an exact match (by name) is found; $null otherwise
#>
Function IO_QueryProjectsByName() {
  Param($IOURL, $IOToken, $ProjectName)
  
  $QueryLimit = 10
  $QueryOffset = 0

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "application/json, text/javascript, */*; q=0.01")
  $Headers.Add("Accept-Language", "en-US,en;q=0.9,ms;q=0.8")
  $Headers.Add("Connection", "keep-alive")
  $Headers.Add("Authorization", "Bearer $IOToken")

  $IOProjectResponse = Invoke-RestMethod "$IOURL/api/ioiq/api/portfolio/projects?_limit=$QueryLimit&_offset=$QueryOffset&_filter=name=ilike=$ProjectName" -Method 'GET' -Headers $Headers
  $ProjectList = $IOProjectResponse._items
  $ProjectCount = $ProjectList.Count

  if($ProjectCount -eq 0) {
    Write-Verbose "No projects found using $IOProjectName as the project-name query."
    return $null
  }

  Write-Verbose "$ProjectCount projects found using $IOProjectName as the project-name query, with a query limit of $QueryLimit."
  ForEach ($Project in $ProjectList) {
    if ($IOProjectName -eq $($Project.name)) {
      Write-Verbose "Found project matching $IOProjectName by name."
      return $Project
    }
  }

  Write-Verbose "No projects exact-matched using $IOProjectName as the project-name query."
  return $null
}

<#
## Get the Synopsys High Risk Profile Policy from Intelligent Orchestration
## Requires: IO Server URL, Access Token
## Returns: Synopsys High Risk Profile Policy Id
#>
Function IO_GetHighRiskProfilePolicy() {
  Param($IOURL, $IOToken)
  
  $QueryLimit = 1
  $QueryOffset = 0

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "application/json, text/javascript, */*; q=0.01")
  $Headers.Add("Accept-Language", "en-US,en;q=0.9,ms;q=0.8")
  $Headers.Add("Connection", "keep-alive")
  $Headers.Add("Authorization", "Bearer $IOToken")

  $RiskProfilePolicyResponse = Invoke-RestMethod "$IOURL/api/ioiq/api/policy/risk-profile-policies?_limit=$QueryLimit&_offset=$QueryOffset" -Method 'GET' -Headers $Headers

  return $($RiskProfilePolicyResponse._items[0].id)
}

<#
## Get the Synopsys Pre-Scan Policy from Intelligent Orchestration
## Requires: IO Server URL, Access Token
## Returns: Synopsys Pre-Scan Policy Id
#>
Function IO_GetSynopsysPreScanPolicy() {
  Param($IOURL, $IOToken)
  
  $QueryLimit = 1
  $QueryOffset = 0

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "application/json, text/javascript, */*; q=0.01")
  $Headers.Add("Accept-Language", "en-US,en;q=0.9,ms;q=0.8")
  $Headers.Add("Connection", "keep-alive")
  $Headers.Add("Authorization", "Bearer $IOToken")

  $PreScanPolicyResponse = Invoke-RestMethod "$IOURL/api/ioiq/api/policy/prescan-policies?_limit=$QueryLimit&_offset=$QueryOffset" -Method 'GET' -Headers $Headers

  return $($PreScanPolicyResponse._items[0].id)
}

<#
## Get the Synopsys Post-Scan Policy from Intelligent Orchestration
## Requires: IO Server URL, Access Token
## Returns: Synopsys Post-Scan Policy Id
#>
Function IO_GetSynopsysPostScanPolicy() {
  Param($IOURL, $IOToken)
  
  $QueryLimit = 1
  $QueryOffset = 0

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "application/json, text/javascript, */*; q=0.01")
  $Headers.Add("Accept-Language", "en-US,en;q=0.9,ms;q=0.8")
  $Headers.Add("Connection", "keep-alive")
  $Headers.Add("Authorization", "Bearer $IOToken")

  $PostScanPolicyResponse = Invoke-RestMethod "$IOURL/api/ioiq/api/policy/post-scan-policies?_limit=$QueryLimit&_offset=$QueryOffset" -Method 'GET' -Headers $Headers

  return $($PostScanPolicyResponse._items[0].id)
}

<#
## Create a project on IO
## Requires: IO Server URL, Access Token, Project Name, Project Language
## Returns: IO Project
#>
Function IO_CreateProject() {
  Param($IOURL, $IOToken, $ProjectName, $ProjectLanguage)
  
  if(-Not ($ValidProjectLanguages.ContainsKey($ProjectLanguage))) {
    Write-Error "Invalid project language provided."
    Exit 1
  }
  
  $BuildSystem = $ValidProjectLanguages[$ProjectLanguage][0]
  $PlatformVersion = $ValidProjectLanguages[$ProjectLanguage][1]
  
  $ProjectType = "WEB_APPLICATION"
  $FileChangeThreshold = 10
  $SensitivePackagePattern = ".*(\\+\\+\\+.*(\\/((a|A)pp|(c|C)rypto|(a|A)uth|(s|S)ec|(l|L)ogin|(p|P)ass|(o|O)auth|(t|T)oken|(i|I)d|(c|C)red|(s|S)aml|(c|C)ognito|(s|S)ignin|(s|S)ignup|(a|A)ccess))).*`",`"sourceFilePattern`":`".*\\/src\\/.*"
  
  $RiskProfilePolicyId = IO_GetHighRiskProfilePolicy $IOURL $IOToken
  $PreScanPolicyId = IO_GetSynopsysPreScanPolicy $IOURL $IOToken
  $PostScanPolicyId = IO_GetSynopsysPostScanPolicy $IOURL $IOToken

  $Headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
  $Headers.Add("Accept", "application/vnd.synopsys.io.projects-2+json")
  $Headers.Add("Accept-Language", "en-US,en;q=0.9,ms;q=0.8")
  $Headers.Add("Content-Type", "application/vnd.synopsys.io.projects-2+json")
  $Headers.Add("Connection", "keep-alive")
  $Headers.Add("Authorization", "Bearer $IOToken")
  
  $Body = "{`"name`":`"$ProjectName`",`"buildSystem`":`"$BuildSystem`",`"fileChangeThreshold`":$FileChangeThreshold,`"platformVersion`":`"$PlatformVersion`",`"projectLanguage`":`"$ProjectLanguage`",`"projectType`":`"$ProjectType`",`"sensitivePackagePattern`":`"$SensitivePackagePattern`",`"prescanPolicyId`":`"$PreScanPolicyId`",`"postScanPolicyId`":`"$PostScanPolicyId`",`"riskProfilePolicyId`":`"$RiskProfilePolicyId`"}"

  $ProjectResponse = Invoke-RestMethod "$IOURL/api/ioiq/api/portfolio/projects" -Method 'GET' -Headers $Headers -Body $Body
  $ProjectResponse | CovertTo-Json

  return $ProjectResponse
}
