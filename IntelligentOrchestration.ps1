<#
## Intelligent Orchestration
#>

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
