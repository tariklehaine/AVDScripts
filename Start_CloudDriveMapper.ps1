<#
.SYNOPSIS
    Imports the Start CloudDriveMapper scheduled task from XML located in C:\Temp.

.DESCRIPTION
    Reads C:\Temp\Start_CloudDriveMapper.xml
    and (re)creates the scheduled task named “Start CloudDriveMapper”
    with all triggers, principals, actions and settings exactly as in the XML.

.PARAMETER TaskName
    Name under which to register the task. Defaults to “Start CloudDriveMapper”.

.EXAMPLE
    PS> .\Create-StartCloudDriveMapperTask.ps1
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$TaskName = 'Start CloudDriveMapper'
)

# Path to your XML
$XmlPath = '.\Start_CloudDriveMapper.xml'

# Ensure running as admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
          ).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
    Write-Warning "This script must be run as Administrator."
    exit 1
}

# Verify XML file exists
if (-not (Test-Path $XmlPath)) {
    Write-Error "Task XML file not found: $XmlPath"
    exit 1
}

try {
    # Read the XML in one string
    $xmlContent = Get-Content -Path $XmlPath -Raw -ErrorAction Stop

    # Import (or overwrite) the scheduled task
    Register-ScheduledTask `
        -TaskName $TaskName `
        -Xml $xmlContent `
        -Force -ErrorAction Stop

    Write-Host "Scheduled task '$TaskName' registered successfully." -ForegroundColor Green
}
catch {
    Write-Error "Failed to register scheduled task: $_"
    exit 1
}
