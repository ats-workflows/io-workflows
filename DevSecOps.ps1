<#
## DevSecOps script to run AST through Intelligent Orchestration
#>

# Named input parameters to this script
Param(
  $IOURL = "",
  $IOToken = "",
  $PolarisURL = "",
  $PolarisToken = "",
  $CodeDxURL = "",
  $CodeDxToken = "",
  $RepositoryOwner = "",
  $RepositoryName = "",
  $BranchName = "",
  $GitHubUserName = "",
  $GitHubAccessToken = "",
  $VerboseOption = "")
#---------------------------------------------------------------------------------------------------

$VerbosePreference = $VerboseOption
Get-Date -DisplayHint Date
Write-Host "Initial directory: $PWD"

# IO Parameters
$IOWorkflowEngineVersion = "2022.7.1"
$IOStateJSON = "io_state.json"
$IOError = "false"
$IOBaseCommand_Linux = "/opt/synopsys_io/bin/io "
$IOBaseCommand_Windows = "io.exe "
#---------------------------------------------------------------------------------------------------

<#
## Source (include) scripts with helper functions
#>
. "$PWD/.synopsys/IntelligentOrchestration.ps1"
. "$PWD/.synopsys/Polaris.ps1"
. "$PWD/.synopsys/CodeDx.ps1"
#---------------------------------------------------------------------------------------------------

# Authenticate with Polaris (Use access token to get JWT - required for subsequent Polaris API calls)
$PolarisJWT = Polaris_Authenticate $PolarisURL $PolarisToken
#---------------------------------------------------------------------------------------------------

<#
## Health Checks
#>
IO_HealthCheck $IOURL
Dx_HealthCheck $CodeDxURL
Polaris_HealthCheck $PolarisURL $PolarisJWT
#---------------------------------------------------------------------------------------------------
