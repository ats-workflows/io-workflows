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
  $OS = "",
  $VerboseOption = "")
#---------------------------------------------------------------------------------------------------

$VerbosePreference = $VerboseOption
Get-Date -DisplayHint Date
Write-Host "Initial directory: $PWD"
$OriginalPath = Get-Location

# IO Parameters
$IOWorkflowEngineVersion = "2022.7.1"
$IOStateJSON = "io_state.json"
$IOError = "false"
$IOBaseCommand_Linux = "/home/io "
$IOBaseCommand_Windows = "io.exe "
$IOBaseCommand_macOS = "./io "
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
#---------------------------------------------------------------------------------------------------

<#
## Intelligent Orchestration - Onboarding
#>
$IOProject = IO_QueryProjectsByName $IOURL $IOToken $ProjectName
if ($IOProject -eq $null){
  Write-Host "No project exists by name: $ProjectName"
  $IOProject = IO_CreateProject $IOURL $IOToken $ProjectName $ProjectLanguage
  Write-Host "Created project by name: $ProjectName with the default properties and policies - a manual edit of the project's configuration is required."
} else {
  Write-Host "$ProjectName exists on IO."
}
#---------------------------------------------------------------------------------------------------

<#
## Intelligent Orchestration - Prescription
## Running: `io --stage io` will produce: "io_state.json" with prescription values for AST.
## If there is an error or a missing parameter, all AST will be prescribed (values will be set to 'true') for all non-dynamic activities (sast, dast, sca)
## If there is an error, dynamic activities (cloud/infra/threat-model) will not be added to the state JSON
#>
# Set the right base command based on platform
$IO_StageIO = ""
$StageIO_Options = "--stage io persona.type='devsecops' io.server.token='$IOToken' io.server.url='$IOURL' project.name='$ProjectName' project.application.name='$ProjectName' "
$StageIO_SCM = "scm.type='github' scm.owner='$RepositoryOwner' scm.repository.branch.name='$BranchName' scm.repository.name='$RepositoryName' "
$StageIO_GitHub = "github.apiurl='https://api.github.com/repos' github.ownername='$GitHubUserName' github.repositoryname='$RepositoryName' github.token='$GitHubAccessToken' github.username='$GitHubUserName' "

if ($OS -like "*Linux*") {
  $IO_StageIO = $IOBaseCommand_Linux + $StageIO_Options + $StageIO_SCM + $StageIO_GitHub
} elseif ($OS -like "*Windows*") {
  $IO_StageIO = $IOBaseCommand_Windows + $StageIO_Options + $StageIO_SCM + $StageIO_GitHub
} elseif ($OS -like "*macOS*") {
  $IO_StageIO = $IOBaseCommand_macOS + $StageIO_Options + $StageIO_SCM + $StageIO_GitHub
} else {
  Write-Error "Unknown build type."
  Exit
}

Write-Host "=========="
Write-Host "IO - Stage IO (Prescription)"
Write-Host "=========="
Invoke-Expression $IO_StageIO

# Running stage IO should result in a state/prescription JSON
if (-Not (Test-Path -Path "$IOStateJSON" -PathType Leaf)) {
  $IOError = "true"
} else {
  $PrescriptionJSON = Get-Content 'io_state.json' | Out-String | ConvertFrom-Json -AsHashTable
  $RunId = $PrescriptionJSON.data.io.run.id
  $RunResponse = IO_OrchestrationRunDetails $IOURL $IOToken $RunId
  Write-Host "$($RunResponse.preScan.prescription.activities)"
}
#---------------------------------------------------------------------------------------------------

<#
## Polaris - Onboarding
#>
