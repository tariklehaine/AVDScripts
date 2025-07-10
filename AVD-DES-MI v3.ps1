# Azure Disk Encryption Script for AVD Hosts
# This script enables Azure Disk Encryption on AVD hosts (VMs starting with AVDH or AVDE)
# using a specified Disk Encryption Set

# Connect to Azure using the Automation Account's Managed Identity
try {
    Connect-AzAccount -Identity
    Write-Output "Successfully connected using Managed Identity"
} 
catch {
    Write-Error "Failed to connect using Managed Identity: $_"
    exit 1
}

# Set variables
$subscriptionId = "2391ada8-feb5-4198-8876-abc31d30a5d5"
$resourceGroupName = "DESKTOPS"
$diskEncryptionSetName = "AVD-DES"

# Create arrays to track results
$successfulVMs = @()
$skippedVMs = @()
$failedVMs = @()

# Set the subscription context
try {
    Set-AzContext -SubscriptionId $subscriptionId
    Write-Output "Successfully set context to subscription: $subscriptionId"
} 
catch {
    Write-Error "Failed to set subscription context: $_"
    exit 1
}

# Get Disk Encryption Set
try {
    $diskEncryptionSet = Get-AzDiskEncryptionSet -ResourceGroupName $resourceGroupName -Name $diskEncryptionSetName
    Write-Output "Successfully retrieved Disk Encryption Set: $diskEncryptionSetName"
} 
catch {
    Write-Error "Failed to retrieve Disk Encryption Set: $_"
    exit 1
}

# Get all VMs in the resource group that match the naming pattern
try {
    $vms = Get-AzVM -ResourceGroupName $resourceGroupName | Where-Object { $_.Name -match '^(AVDH|AVDE)' }
    $vmCount = $vms.Count
    Write-Output "Found $vmCount VMs matching the AVDH or AVDE pattern"
} 
catch {
    Write-Error "Failed to retrieve VMs: $_"
    exit 1
}

if ($vmCount -eq 0) {
    Write-Output "No VMs found matching the pattern. Exiting script."
    exit 0
}

# Loop through each VM and enable encryption
foreach ($vm in $vms) {
    $vmName = $vm.Name
    $skipReason = ""
    Write-Output "Processing VM: $vmName"
    
    # Check for Azure Disk Encryption (ADE) - which is different from server-side encryption with DES
    try {
        $adeStatus = Get-AzVMDiskEncryptionStatus -ResourceGroupName $resourceGroupName -VMName $vmName
        $isAdeEncrypted = $adeStatus.OsVolumeEncrypted -eq "Encrypted" -or $adeStatus.DataVolumesEncrypted -eq "Encrypted"
        
        if ($isAdeEncrypted) {
            $skipReason = "Already encrypted with Azure Disk Encryption (ADE)"
            Write-Output "SKIPPING VM $vmName - $skipReason. Cannot apply server-side encryption with customer managed keys via Disk Encryption Set."
            Write-Output "Please refer to https://docs.microsoft.com/en-us/azure/virtual-machines/windows/disk-encryption-windows#unsupported-scenarios for current restrictions."
            $skippedVMs += [PSCustomObject]@{
                VMName = $vmName
                Reason = $skipReason
            }
            continue
        }
    }
    catch {
        Write-Output "Could not determine ADE status for VM $vmName. Will attempt to check disk properties directly."
    }
    
    # Additional check through disk properties
    try {
        $osDisk = Get-AzDisk -ResourceGroupName $resourceGroupName -DiskName $vm.StorageProfile.OsDisk.Name
        
        # Check if disk was previously encrypted with ADE
        if ($osDisk.EncryptionSettingsCollection -and $osDisk.EncryptionSettingsCollection.Enabled -eq $true) {
            $skipReason = "OS disk '$($osDisk.Name)' was previously encrypted with Azure Disk Encryption (ADE)"
            Write-Output "SKIPPING VM $vmName - $skipReason. Cannot apply server-side encryption with customer managed keys."
            Write-Output "Please refer to https://docs.microsoft.com/en-us/azure/virtual-machines/windows/disk-encryption-windows#unsupported-scenarios for current restrictions."
            $skippedVMs += [PSCustomObject]@{
                VMName = $vmName
                Reason = $skipReason
            }
            continue
        }
    }
    catch {
        Write-Output "Warning: Could not check disk encryption properties for VM $vmName. Will proceed with caution. Error: $_"
    }
    
    # Check if VM is already encrypted with DES
    try {
        $osDisk = Get-AzDisk -ResourceGroupName $resourceGroupName -DiskName $vm.StorageProfile.OsDisk.Name
        if ($osDisk.Encryption -and $osDisk.Encryption.Type -eq "EncryptionAtRestWithCustomerKey") {
            $skipReason = "Already encrypted with server-side encryption using customer managed keys"
            Write-Output "VM $vmName is $skipReason. Skipping."
            $skippedVMs += [PSCustomObject]@{
                VMName = $vmName
                Reason = $skipReason
            }
            continue
        }
    }
    catch {
        Write-Output "Warning: Could not determine current encryption status for VM $vmName. Error: $_"
    }
    
    # Check VM power state - encryption requires VM to be stopped
    $vmStatus = (Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Status).Statuses | 
                Where-Object { $_.Code -match "PowerState" }
    
    $isPoweredOff = $vmStatus.DisplayStatus -eq "VM deallocated" -or $vmStatus.DisplayStatus -eq "VM stopped"
    
    if (-not $isPoweredOff) {
        Write-Output "VM $vmName is currently running. Stopping VM..."
        
        try {
            Stop-AzVM -ResourceGroupName $resourceGroupName -Name $vmName -Force
            Write-Output "VM $vmName stopped successfully."
        } 
        catch {
            Write-Error "Failed to stop VM $vmName. Error: $_"
            $failedVMs += [PSCustomObject]@{
                VMName = $vmName
                Reason = "Failed to stop VM: $_"
            }
            continue
        }
    }
    
    # Enable encryption
    try {
        # Get all disks associated with the VM
        $osDisk = $vm.StorageProfile.OsDisk
        $dataDisks = $vm.StorageProfile.DataDisks
        
        # Update OS disk with encryption
        Write-Output "Updating OS disk encryption for VM $vmName..."
        $osDisk = Get-AzDisk -ResourceGroupName $resourceGroupName -DiskName $osDisk.Name
        $osDisk.Encryption = New-Object Microsoft.Azure.Management.Compute.Models.Encryption
        $osDisk.Encryption.DiskEncryptionSetId = $diskEncryptionSet.Id
        $osDisk.Encryption.Type = "EncryptionAtRestWithCustomerKey"
        
        Update-AzDisk -ResourceGroupName $resourceGroupName -DiskName $osDisk.Name -Disk $osDisk
        Write-Output "OS disk encryption updated successfully for VM $vmName."
        
        # Update data disks with encryption (if any)
        if ($dataDisks.Count -gt 0) {
            Write-Output "Updating data disk encryption for VM $vmName..."
            
            foreach ($dataDiskRef in $dataDisks) {
                $dataDisk = Get-AzDisk -ResourceGroupName $resourceGroupName -DiskName $dataDiskRef.Name
                $dataDisk.Encryption = New-Object Microsoft.Azure.Management.Compute.Models.Encryption
                $dataDisk.Encryption.DiskEncryptionSetId = $diskEncryptionSet.Id
                $dataDisk.Encryption.Type = "EncryptionAtRestWithCustomerKey"
                
                Update-AzDisk -ResourceGroupName $resourceGroupName -DiskName $dataDisk.Name -Disk $dataDisk
                Write-Output "Data disk $($dataDisk.Name) encryption updated successfully."
            }
        }
        
        Write-Output "Encryption enabled successfully for VM $vmName"
        $successfulVMs += $vmName
        
        # Start the VM if it was running before
        if (-not $isPoweredOff) {
            Write-Output "Starting VM $vmName..."
            Start-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
            Write-Output "VM $vmName started successfully."
        }
    } 
    catch {
        $errorMessage = $_.Exception.Message
        Write-Error "Failed to enable encryption on VM $vmName. Error: $errorMessage"
        
        # Special handling for the specific ADE error
        if ($errorMessage -match "was previously encrypted with Azure Disk Encryption") {
            $skipReason = "Was previously encrypted with Azure Disk Encryption (ADE)"
            Write-Output "SKIPPING VM $vmName - $skipReason. Cannot apply server-side encryption with customer managed keys."
            Write-Output "Please refer to https://docs.microsoft.com/en-us/azure/virtual-machines/windows/disk-encryption-windows#unsupported-scenarios for current restrictions."
            $skippedVMs += [PSCustomObject]@{
                VMName = $vmName
                Reason = $skipReason
            }
        }
        else {
            $failedVMs += [PSCustomObject]@{
                VMName = $vmName
                Reason = $errorMessage
            }
        }
        
        # Try to start the VM if we stopped it but failed to encrypt
        if (-not $isPoweredOff) {
            try {
                Write-Output "Attempting to restart VM $vmName after encryption failure..."
                Start-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
                Write-Output "VM $vmName restarted successfully."
            } 
            catch {
                Write-Error "Failed to restart VM $vmName after encryption failure. Error: $_"
            }
        }
    }
}

# Display final report
Write-Output "`n===== ENCRYPTION SUMMARY ====="
Write-Output "Total VMs processed: $vmCount"

Write-Output "`nSUCCESSFULLY ENCRYPTED VMs ($($successfulVMs.Count)):"
if ($successfulVMs.Count -gt 0) {
    foreach ($vm in $successfulVMs) {
        Write-Output "- $vm"
    }
} else {
    Write-Output "- No VMs were successfully encrypted"
}

Write-Output "`nSKIPPED VMs ($($skippedVMs.Count)):"
if ($skippedVMs.Count -gt 0) {
    foreach ($skippedVM in $skippedVMs) {
        Write-Output "- $($skippedVM.VMName): $($skippedVM.Reason)"
    }
} else {
    Write-Output "- No VMs were skipped"
}

Write-Output "`nFAILED VMs ($($failedVMs.Count)):"
if ($failedVMs.Count -gt 0) {
    foreach ($failedVM in $failedVMs) {
        Write-Output "- $($failedVM.VMName): $($failedVM.Reason)"
    }
} else {
    Write-Output "- No VMs failed encryption"
}

Write-Output "`nScript completed. Check the summary above for details."