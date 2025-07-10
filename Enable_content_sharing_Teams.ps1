# PowerShell script to enable content sharing via WebRTC Redirector
# Run this with administrative privileges

# Registry path for WebRTC Redirector Policy
$registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\AddIns\WebRTC Redirector\Policy"

# Check if the registry path exists, create it if it doesn't
if (-not (Test-Path -Path $registryPath)) {
    try {
        Write-Host "Creating registry path: $registryPath" -ForegroundColor Yellow
        New-Item -Path $registryPath -Force | Out-Null
        Write-Host "Registry path created successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "Error creating registry path: $_" -ForegroundColor Red
        exit 1
    }
}

# Set the ShareClientDesktop DWORD value to 1
try {
    Write-Host "Setting ShareClientDesktop value to 1..." -ForegroundColor Yellow
    New-ItemProperty -Path $registryPath -Name "ShareClientDesktop" -Value 1 -PropertyType DWORD -Force | Out-Null
    Write-Host "Content sharing has been successfully enabled." -ForegroundColor Green
}
catch {
    Write-Host "Error setting registry value: $_" -ForegroundColor Red
    exit 1
}

# Verify the configuration
$verifyValue = Get-ItemProperty -Path $registryPath -Name "ShareClientDesktop" -ErrorAction SilentlyContinue
if ($verifyValue -and $verifyValue.ShareClientDesktop -eq 1) {
    Write-Host "Verification successful: ShareClientDesktop is enabled." -ForegroundColor Green
}
else {
    Write-Host "Verification failed: ShareClientDesktop setting could not be confirmed." -ForegroundColor Red
}