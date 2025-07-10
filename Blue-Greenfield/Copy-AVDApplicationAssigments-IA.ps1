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

# Azure Virtual Desktop - Assign Entra ID Group to All Application Groups in Host Pool
# Variables
$subscriptionId = "2391ada8-feb5-4198-8876-abc31d30a5d5"
$resourceGroupName = "DESKTOPS"
$hostPoolName = "HP03"
$entraGroupObjectId = "41f295a7-0e00-4d2c-bbe0-084fd6aa2f66"

# Connect to Azure (if not already connected)
try {
    $context = Get-AzContext
    if (-not $context) {
        Write-Host "Connecting to Azure..." -ForegroundColor Yellow
        Connect-AzAccount
    }
} catch {
    Write-Host "Connecting to Azure..." -ForegroundColor Yellow
    Connect-AzAccount
}

# Set the subscription context
Write-Host "Setting subscription context to: $subscriptionId" -ForegroundColor Green
Set-AzContext -SubscriptionId $subscriptionId

# Get all application groups in the specified host pool
Write-Host "Getting application groups for host pool: $hostPoolName" -ForegroundColor Green
try {
    $applicationGroups = Get-AzWvdApplicationGroup -ResourceGroupName $resourceGroupName | Where-Object { $_.HostPoolArmPath -like "*$hostPoolName*" }
    
    if ($applicationGroups.Count -eq 0) {
        Write-Warning "No application groups found for host pool '$hostPoolName' in resource group '$resourceGroupName'"
        exit
    }
    
    Write-Host "Found $($applicationGroups.Count) application group(s):" -ForegroundColor Green
    foreach ($appGroup in $applicationGroups) {
        Write-Host "  - $($appGroup.Name)" -ForegroundColor Cyan
    }
} catch {
    Write-Error "Failed to retrieve application groups: $($_.Exception.Message)"
    exit
}

# Assign the Entra ID group to each application group
Write-Host "`nAssigning Entra ID group (ObjectId: $entraGroupObjectId) to application groups..." -ForegroundColor Green

$successCount = 0
$failureCount = 0

foreach ($appGroup in $applicationGroups) {
    try {
        Write-Host "Processing application group: $($appGroup.Name)" -ForegroundColor Yellow
        
        # Check if the group is already assigned
        $existingAssignments = Get-AzRoleAssignment -ObjectId $entraGroupObjectId -Scope $appGroup.Id -ErrorAction SilentlyContinue
        $desktopUserRole = $existingAssignments | Where-Object { $_.RoleDefinitionName -eq "Desktop Virtualization User" }
        
        if ($desktopUserRole) {
            Write-Host "  Group is already assigned to $($appGroup.Name)" -ForegroundColor Blue
        } else {
            # Assign the "Desktop Virtualization User" role to the Entra ID group
            New-AzRoleAssignment -ObjectId $entraGroupObjectId -RoleDefinitionName "Desktop Virtualization User" -Scope $appGroup.Id
            Write-Host "  Successfully assigned group to $($appGroup.Name)" -ForegroundColor Green
            $successCount++
        }
    } catch {
        Write-Error "  Failed to assign group to $($appGroup.Name): $($_.Exception.Message)"
        $failureCount++
    }
}

# Summary
Write-Host "`n=== Assignment Summary ===" -ForegroundColor Magenta
Write-Host "Successfully assigned: $successCount" -ForegroundColor Green
Write-Host "Failed assignments: $failureCount" -ForegroundColor Red
Write-Host "Total application groups processed: $($applicationGroups.Count)" -ForegroundColor Cyan

if ($failureCount -eq 0) {
    Write-Host "`nAll assignments completed successfully!" -ForegroundColor Green
} else {
    Write-Host "`nSome assignments failed. Please review the errors above." -ForegroundColor Yellow
}