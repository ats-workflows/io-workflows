<#
## DevSecOps script to run AST through Intelligent Orchestration
#>

# Named input parameters to this script
Param(
  $IOURL = "",
  $IOToken = "",
  $PolarisURL = "",
  $PolarisToken = "",
  $BlackDuckURL = "",
  $BlackDuckToken = "",
  $CodeDxURL = "",
  $CodeDxToken = "",
  $GitHubUserName = "",
  $GitHubAccessToken = "",
  $RepositoryOwner = "",
  $RepositoryName = "",
  $ProjectName = "",
  $ProjectVersion = "",
  $BranchName = "",
  $ProjectLanguage = "",
  $OS = "",
  $VerboseOption = "")
#---------------------------------------------------------------------------------------------------

$VerbosePreference = $VerboseOption
Get-Date -DisplayHint Date
Write-Host "Initial directory: $PWD"
# Print current directory contents (including hidden files and folders)
#Get-ChildItem -Path $PWD -Force | Select-Object Size, Name
$OriginalPath = Get-Location

# IO Parameters
$IOWorkflowEngineVersion = "2022.7.1"
$IOStateJSON = "io_state.json"
$IOLog = "io.log"
$IOError = "false"
$IOBaseCommand_Linux = "/home/io "
$IOBaseCommand_Windows = "io.exe "
$IOBaseCommand_macOS = "./io "
#---------------------------------------------------------------------------------------------------

<#
## Import (include) modules (scripts with helper functions)
#>
if ($OS -like "*Windows*") {
  Set-ExecutionPolicy -ExecutionPolicy Unrestricted
  $IOModule = Join-Path $PWD 'Modules' 'IntelligentOrchestration.psm1'
  $CodeDxModule = Join-Path $PWD 'Modules' 'CodeDx.psm1'
  $PolarisModule = Join-Path $PWD 'Modules' 'Polaris.psm1'
} else {
  $IOModule = Join-Path $PWD '.synopsys' 'Modules' 'IntelligentOrchestration.psm1'
  $CodeDxModule = Join-Path $PWD '.synopsys' 'Modules' 'CodeDx.psm1'
  $PolarisModule = Join-Path $PWD '.synopsys' 'Modules' 'Polaris.psm1'
}

Import-Module -Name $IOModule
Import-Module -Name $CodeDxModule
Import-Module -Name $PolarisModule
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
if ($null -eq $IOProject){
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
  Write-Error "Unsupported OS/Architecture ( $OS )."
  Exit
}

Write-Host "=========="
Write-Host "IO - Stage IO (Prescription)"
Write-Host "=========="
Invoke-Expression $IO_StageIO | Out-Null

# Running stage IO should result in a state/prescription JSON
if (-Not (Test-Path -Path "$IOStateJSON" -PathType Leaf)) {
  $IOError = "true"
  Write-Error "No state JSON generated by IO. Prescribing all default security activities..."
} else {
  $PrescriptionJSON = Get-Content "$IOStateJSON" | Out-String | ConvertFrom-Json -AsHashTable
  $RunId = $PrescriptionJSON.data.io.run.id
  $PrescribedActivities = IO_PrintPrescriptionExplanation $IOURL $IOToken $RunId
}
#---------------------------------------------------------------------------------------------------

<#
## Intelligent Orchestration - Execution - SAST
#>
if ($IOError -eq "true" -Or $PrescribedActivities -Contains "sast") {
  Write-Host "Running SAST by prescription..."
  # Write-Host "Last SAST run (scan) date: $($PrescriptionJSON.data.prescription.security.activities.sast.lastScanDate)"
  
  # Set the right base command based on platform
  $IO_StageExecution_Polaris = ""
  $StageExecution_Options = "--stage execution --state $IOStateJSON "
  $StageExecution_Polaris = "polaris.instanceurl='$PolarisURL' polaris.authtoken='$PolarisToken' polaris.BranchName='$BranchName' polaris.projectname='$ProjectName'"

  if ($OS -like "*Linux*") {
    $IO_StageExecution_Polaris = $IOBaseCommand_Linux + $StageExecution_Options + $StageExecution_Polaris
  } elseif ($OS -like "*Windows*") {
    $IO_StageExecution_Polaris = $IOBaseCommand_Windows + $StageExecution_Options + $StageExecution_Polaris
  } elseif ($OS -like "*macOS*") {
    $IO_StageExecution_Polaris = $IOBaseCommand_macOS + $StageExecution_Options + $StageExecution_Polaris
  } else {
    Write-Error "Unsupported OS/Architecture ( $OS )."
  }
  
  Write-Host "=========="
  Write-Host "IO - Stage Execution - Polaris"
  Write-Host "=========="
  Invoke-Expression $IO_StageExecution_Polaris
  
  # Validate Polaris automation
  Polaris_Validate $IOLog $ProjectLanguage
 }
#---------------------------------------------------------------------------------------------------

<#
## Intelligent Orchestration - Execution - SCA
#>
if ($IOError -eq "true" -Or $PrescribedActivities -Contains "sca") {
  Write-Host "Running SCA by prescription..."
  
  $LoadPath = Join-Path $PWD '.synopsys' 'Adapters' 'BlackDuckAdapter.json'
  $MovePath = Join-Path $PWD 'BlackDuckAdapter.json'
  Move-Item $LoadPath -Destination $MovePath
  
  # Set the right base command based on platform
  $IO_StageExecution_BlackDuck = ""
  $StageExecution_Options = "--stage execution --state $IOStateJSON "
  $StageExecution_BlackDuck = "blackduck.authtoken='$BlackDuckToken' blackduck.instanceurl='$BlackDuckURL' blackduck.projectname='$ProjectName' blackduck.projectversion='$ProjectVersion' --adapters BlackDuckAdapter.json"

  if ($OS -like "*Linux*") {
    $IO_StageExecution_BlackDuck = $IOBaseCommand_Linux + $StageExecution_Options + $StageExecution_BlackDuck
  } elseif ($OS -like "*Windows*") {
    $IO_StageExecution_BlackDuck = $IOBaseCommand_Windows + $StageExecution_Options + $StageExecution_BlackDuck
  } elseif ($OS -like "*macOS*") {
    $IO_StageExecution_BlackDuck = $IOBaseCommand_macOS + $StageExecution_Options + $StageExecution_BlackDuck
  } else {
    Write-Error "Unsupported OS/Architecture ( $OS )."
  }
  
  Write-Host "=========="
  Write-Host "IO - Stage Execution - Black Duck"
  Write-Host "=========="
  Invoke-Expression $IO_StageExecution_BlackDuck
 }
#---------------------------------------------------------------------------------------------------

<#
## Intelligent Orchestration - Workflow (Post-Scan)
#>
# Set the right base command based on platform
$IO_StageWorkflow = ""
$StageWorkflow_Options = "--stage workflow --state $IOStateJSON workflow.engine.version='2022.12.0'"

if ($OS -like "*Linux*") {
  $IO_StageWorkflow = $IOBaseCommand_Linux + $StageWorkflow_Options 
} elseif ($OS -like "*Windows*") {
  $IO_StageWorkflow = $IOBaseCommand_Windows + $StageWorkflow_Options
} elseif ($OS -like "*macOS*") {
  $IO_StageWorkflow = $IOBaseCommand_macOS + $StageWorkflow_Options
} else {
  Write-Error "Unsupported OS/Architecture ( $OS )."
}
  
Write-Host "=========="
Write-Host "IO - Stage Workflow"
Write-Host "=========="
Invoke-Expression $IO_StageWorkflow
#---------------------------------------------------------------------------------------------------

<#
## Cleanup
#>
Write-Host "=========="
if (Test-Path -Path "$IOStateJSON" -PathType Leaf) {
  Write-Host "Removing $IOStateJSON"
  Remove-Item -Path "$IOStateJSON"
}
Write-Host "=========="
#------------------------------------------------------------------------------------------------FIN
