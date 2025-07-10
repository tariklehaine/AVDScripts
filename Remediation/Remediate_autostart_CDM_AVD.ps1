# Remediation script for Intune Proactive Remediation
# Create or update Cloud Drive Mapper in Run registry for the current user

$RegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$Name = "Cloud Drive Mapper"
$Value = "C:\Program Files\IAM Cloud\Cloud Drive Mapper\Cloud Drive Mapper.exe"

try {
    # Check if registry path exists, if not create it
    if (!(Test-Path $RegistryPath)) {
        New-Item -Path $RegistryPath -Force | Out-Null
        Write-Output "Registry path created: $RegistryPath"
    }
    
    # Create or update the registry value
    New-ItemProperty -Path $RegistryPath -Name $Name -Value $Value -PropertyType String -Force | Out-Null
    Write-Output "Registry value '$Name' created/updated successfully."
    
    # Verify the change
    $VerifyValue = Get-ItemProperty -Path $RegistryPath -Name $Name -ErrorAction SilentlyContinue
    
    if ($VerifyValue.$Name -eq $Value) {
        Write-Output "Verification successful. Registry value is set correctly."
        exit 0
    } else {
        Write-Error "Verification failed. Registry value was not set correctly."
        exit 1
    }
} catch {
    Write-Error "Error occurred: $_"
    exit 1
}