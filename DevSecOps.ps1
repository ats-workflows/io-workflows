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
  $GitHubUserName = "",
  $GitHubAccessToken = "",
  $RepositoryOwner = "",
  $RepositoryName = "",
  $ProjectName = "",
  $BranchName = "",
  $ProjectLanguage = "",
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

<#
## Inputs
#>
Write-Host "=========="
Write-Host "Project Name: $ProjectName"
Write-Host "Branch Name: $BranchName"
Write-Host "Project Language: $ProjectLanguage"
Write-Host "Repository Owner Name: $RepositoryOwner"
Write-Host "Repository Name: $RepositoryName"
Write-Host "=========="

<#
## Intelligent Orchestration - Onboarding
#>
$IOProject = IO_QueryProjectsByName $IOURL $IOToken $ProjectName
if ($IOProject -eq $null){
  Write-Host "No project exists by name: $ProjectName"
  $IOProject = IO_CreateProject $IOURL $IOToken $ProjectName $ProjectLanguage
  Write-Host "$IOProject"
  Write-Host "Created project by name: $ProjectName with the default (high-risk) profile - manual edit of the project's configuration requried."
}
