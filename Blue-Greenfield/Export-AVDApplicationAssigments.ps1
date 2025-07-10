# Azure Virtual Desktop Application Assignments Export Script
# This script exports all application assignments from a specified host pool to CSV

# Parameters
param(
    [Parameter(Mandatory=$false)]
    [string]$HostPoolName,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath
)

# Hardcoded values
$SubscriptionId = "2391ada8-feb5-4198-8876-abc31d30a5d5"
$ResourceGroupName = "DESKTOPS"

# Ask for HostPoolName if not provided
if (-not $HostPoolName) {
    $HostPoolName = Read-Host "Van welke Hostpool moeten de assigments opgehaald worden?"
    if (-not $HostPoolName) {
        Write-Error "HostPoolName is required"
        exit 1
    }
}

# Set default output path with HostPoolName included
if (-not $OutputPath) {
    $OutputPath = "C:\Temp\AVD_ApplicationAssignments_$($HostPoolName)_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
}

# Vereiste modules controleren en installeren indien nodig
$RequiredModules = @("Az.Accounts", "Az.DesktopVirtualization")

foreach ($Module in $RequiredModules) {
    if (Get-Module -ListAvailable -Name $Module) {
        Write-Host "Module $Module is al geinstalleerd" -ForegroundColor Green
    } else {
        Write-Host "Installeren van module $Module..." -ForegroundColor Yellow
        Install-Module -Name $Module -Force
    }
    
    # Importeer de module als deze nog niet geladen is
    if (!(Get-Module -Name $Module)) {
        Write-Host "Importeren van module $Module..." -ForegroundColor Cyan
        Import-Module $Module
    } else {
        Write-Host "Module $Module is al geimporteerd" -ForegroundColor Green
    }
}

# Connect to Azure (if not already connected)
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "Connecting to Azure..." -ForegroundColor Yellow
        Connect-AzAccount
    }
    
    # Set subscription context
    Set-AzContext -SubscriptionId $SubscriptionId
    Write-Host "Connected to subscription: $SubscriptionId" -ForegroundColor Green
}
catch {
    Write-Error "Failed to connect to Azure or set subscription context: $($_.Exception.Message)"
    exit 1
}

# Initialize results array
$results = @()

try {
    # Get all application groups for the specified host pool
    Write-Host "Retrieving application groups for host pool: $HostPoolName" -ForegroundColor Yellow
    $appGroups = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName | Where-Object { $_.HostPoolArmPath -like "*$HostPoolName*" }
    
    if ($appGroups.Count -eq 0) {
        Write-Warning "No application groups found for host pool: $HostPoolName"
        exit 0
    }
    
    Write-Host "Found $($appGroups.Count) application group(s)" -ForegroundColor Green
    
    # Process each application group
    foreach ($appGroup in $appGroups) {
        Write-Host "Processing application group: $($appGroup.Name)" -ForegroundColor Cyan
        
        # Get applications in this application group
        $applications = Get-AzWvdApplication -ResourceGroupName $ResourceGroupName -ApplicationGroupName $appGroup.Name
        
        # Get role assignments for this application group
        $roleAssignments = Get-AzRoleAssignment -Scope $appGroup.Id
        
        # Process role assignments
        foreach ($assignment in $roleAssignments) {
            # Filter for Desktop Virtualization User role (the standard role for AVD access)
            if ($assignment.RoleDefinitionName -eq "Desktop Virtualization User") {
                $assignmentInfo = [PSCustomObject]@{
                    HostPoolName = $HostPoolName
                    ApplicationGroupName = $appGroup.Name
                    ApplicationGroupType = $appGroup.ApplicationGroupType
                    ApplicationGroupResourceId = $appGroup.Id
                    AssignmentType = if ($assignment.ObjectType -eq "User") { "User" } else { "Group" }
                    PrincipalName = $assignment.DisplayName
                    PrincipalId = $assignment.ObjectId
                    PrincipalType = $assignment.ObjectType
                    RoleDefinitionName = $assignment.RoleDefinitionName
                    SignInName = $assignment.SignInName
                    ApplicationCount = $applications.Count
                    Applications = ($applications.Name -join "; ")
                    FriendlyName = $appGroup.FriendlyName
                    Description = $appGroup.Description
                }
                $results += $assignmentInfo
            }
        }
        
        # Also check for any other relevant role assignments
        $otherRoleAssignments = $roleAssignments | Where-Object { 
            $_.RoleDefinitionName -notlike "Desktop Virtualization User" -and 
            ($_.RoleDefinitionName -like "*Desktop*" -or $_.RoleDefinitionName -like "*Virtual*" -or $_.RoleDefinitionName -like "*AVD*")
        }
        
        foreach ($assignment in $otherRoleAssignments) {
            $assignmentInfo = [PSCustomObject]@{
                HostPoolName = $HostPoolName
                ApplicationGroupName = $appGroup.Name
                ApplicationGroupType = $appGroup.ApplicationGroupType
                ApplicationGroupResourceId = $appGroup.Id
                AssignmentType = if ($assignment.ObjectType -eq "User") { "User" } else { "Group" }
                PrincipalName = $assignment.DisplayName
                PrincipalId = $assignment.ObjectId
                PrincipalType = $assignment.ObjectType
                RoleDefinitionName = $assignment.RoleDefinitionName
                SignInName = $assignment.SignInName
                ApplicationCount = $applications.Count
                Applications = ($applications.Name -join "; ")
                FriendlyName = $appGroup.FriendlyName
                Description = $appGroup.Description
            }
            $results += $assignmentInfo
        }
    }
    
    # Export results to CSV
    if ($results.Count -gt 0) {
        $results | Export-Csv -Path $OutputPath -NoTypeInformation -Encoding UTF8
        Write-Host "Successfully exported $($results.Count) assignment(s) to: $OutputPath" -ForegroundColor Green
        
        # Display summary
        Write-Host "`n=== EXPORT SUMMARY ===" -ForegroundColor Magenta
        Write-Host "Host Pool: $HostPoolName" -ForegroundColor White
        Write-Host "Application Groups: $($appGroups.Count)" -ForegroundColor White
        Write-Host "Total Assignments: $($results.Count)" -ForegroundColor White
        Write-Host "User Assignments: $(($results | Where-Object {$_.AssignmentType -eq 'User'}).Count)" -ForegroundColor White
        Write-Host "Group Assignments: $(($results | Where-Object {$_.AssignmentType -eq 'Group'}).Count)" -ForegroundColor White
        Write-Host "Output File: $OutputPath" -ForegroundColor White
        
        # Show first few rows as preview
        if ($results.Count -le 5) {
            Write-Host "`n=== PREVIEW ===" -ForegroundColor Magenta
            $results | Format-Table -AutoSize
        }
    }
    else {
        Write-Warning "No assignments found for host pool: $HostPoolName"
    }
}
catch {
    Write-Error "An error occurred during export: $($_.Exception.Message)"
    Write-Error "Stack trace: $($_.Exception.StackTrace)"
    exit 1
}

Write-Host "`nScript completed successfully!" -ForegroundColor Green