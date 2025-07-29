# Azure Virtual Desktop - Remove Entra ID Group from All Application Groups in Host Pool
# Designed for Azure Automation with Managed Identity

# Variables
$subscriptionId = "2391ada8-feb5-4198-8876-abc31d30a5d5"
$resourceGroupName = "DESKTOPS"
$entraGroupObjectId = "41f295a7-0e00-4d2c-bbe0-084fd6aa2f66"
$hostPoolName = "HP03"  # Static host pool name

# Import required modules (these should be pre-installed in Azure Automation)
try {
    Write-Output "Importing required modules..."
    Import-Module Az.Accounts -Force
    Import-Module Az.DesktopVirtualization -Force
    Write-Output "Modules imported successfully"
} catch {
    Write-Error "Failed to import required modules: $($_.Exception.Message)"
    throw
}

# Connect to Azure using Managed Identity
try {
    Write-Output "Connecting to Azure using Managed Identity..."
    Connect-AzAccount -Identity
    Write-Output "Successfully connected to Azure with Managed Identity"
} catch {
    Write-Error "Failed to connect to Azure with Managed Identity: $($_.Exception.Message)"
    throw
}

# Set the subscription context
try {
    Write-Output "Setting subscription context to: $subscriptionId"
    Set-AzContext -SubscriptionId $subscriptionId
    Write-Output "Subscription context set successfully"
} catch {
    Write-Error "Failed to set subscription context: $($_.Exception.Message)"
    throw
}

# Get all application groups in the specified host pool
Write-Output "Getting application groups for host pool: $hostPoolName"
try {
    $applicationGroups = Get-AzWvdApplicationGroup -ResourceGroupName $resourceGroupName | Where-Object { $_.HostPoolArmPath -like "*$hostPoolName*" }
    
    if ($applicationGroups.Count -eq 0) {
        Write-Warning "No application groups found for host pool '$hostPoolName' in resource group '$resourceGroupName'"
        return
    }
    
    Write-Output "Found $($applicationGroups.Count) application group(s):"
    foreach ($appGroup in $applicationGroups) {
        Write-Output "  - $($appGroup.Name)"
    }
} catch {
    Write-Error "Failed to retrieve application groups: $($_.Exception.Message)"
    throw
}

# Remove the Entra ID group from each application group
Write-Output "`nRemoving Entra ID group (ObjectId: $entraGroupObjectId) from application groups..."

$successCount = 0
$failureCount = 0
$notAssignedCount = 0

foreach ($appGroup in $applicationGroups) {
    try {
        Write-Output "Processing application group: $($appGroup.Name)"
        
        # Check if the group is currently assigned
        $existingAssignments = Get-AzRoleAssignment -ObjectId $entraGroupObjectId -Scope $appGroup.Id -ErrorAction SilentlyContinue
        $desktopUserRole = $existingAssignments | Where-Object { $_.RoleDefinitionName -eq "Desktop Virtualization User" }
        
        if ($desktopUserRole) {
            # Remove the "Desktop Virtualization User" role assignment
            Remove-AzRoleAssignment -ObjectId $entraGroupObjectId -RoleDefinitionName "Desktop Virtualization User" -Scope $appGroup.Id -Confirm:$false
            Write-Output "  Successfully removed group from $($appGroup.Name)"
            $successCount++
        } else {
            Write-Output "  Group is not assigned to $($appGroup.Name) - skipping"
            $notAssignedCount++
        }
    } catch {
        Write-Error "  Failed to remove group from $($appGroup.Name): $($_.Exception.Message)"
        $failureCount++
    }
}

# Summary
Write-Output "`n=== Removal Summary ==="
Write-Output "Successfully removed: $successCount"
Write-Output "Not assigned (skipped): $notAssignedCount"
Write-Output "Failed removals: $failureCount"
Write-Output "Total application groups processed: $($applicationGroups.Count)"

if ($failureCount -eq 0) {
    Write-Output "`nAll removals completed successfully!"
} else {
    Write-Output "`nSome removals failed. Please review the errors above."
    throw "Script completed with $failureCount failures"
}

# Return summary object for potential use in other runbooks
$summary = @{
    HostPoolName = $hostPoolName
    TotalApplicationGroups = $applicationGroups.Count
    SuccessfulRemovals = $successCount
    NotAssigned = $notAssignedCount
    FailedRemovals = $failureCount
    ExecutionTime = Get-Date
}

return $summary