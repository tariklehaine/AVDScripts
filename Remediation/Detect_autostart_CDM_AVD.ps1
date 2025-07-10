# Detection script for Intune Proactive Remediation
# Check if Cloud Drive Mapper is properly configured in Run registry for the current user

$RegistryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$Name = "Cloud Drive Mapper"
$ExpectedValue = "C:\Program Files\IAM Cloud\Cloud Drive Mapper\Cloud Drive Mapper.exe"

# Initialize detection status
$Compliant = $false

# Check if registry path exists
if (Test-Path $RegistryPath) {
    # Check if registry value exists
    $ExistingValue = Get-ItemProperty -Path $RegistryPath -Name $Name -ErrorAction SilentlyContinue
    
    if ($ExistingValue -ne $null) {
        # Check if value is correct
        if ($ExistingValue.$Name -eq $ExpectedValue) {
            $Compliant = $true
            Write-Output "Cloud Drive Mapper is properly configured in startup registry."
        } else {
            Write-Output "Cloud Drive Mapper exists but has incorrect path: $($ExistingValue.$Name)"
        }
    } else {
        Write-Output "Cloud Drive Mapper registry value not found."
    }
} else {
    Write-Output "Registry path does not exist: $RegistryPath"
}

# Exit with appropriate code: 0 for compliant, 1 for non-compliant
if ($Compliant) {
    exit 0
} else {
    exit 1
}