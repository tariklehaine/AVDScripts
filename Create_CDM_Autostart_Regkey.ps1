# Script to add Cloud Drive Mapper to Windows startup via registry

# Define registry path and value
$registryPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$name = "Cloud Drive Mapper"
$value = "C:\Program Files\IAM Cloud\Cloud Drive Mapper\Cloud Drive Mapper.exe"

# Check if the registry path exists
if (!(Test-Path $registryPath)) {
    # Create the full path if it doesn't exist
    Write-Host "Registry path doesn't exist. Creating registry path..."
    try {
        New-Item -Path $registryPath -Force | Out-Null
        Write-Host "Registry path created successfully."
    }
    catch {
        Write-Error "Failed to create registry path: $_"
        exit 1
    }
}
else {
    Write-Host "Registry path already exists."
}

# Check if the registry value already exists
$existingValue = Get-ItemProperty -Path $registryPath -Name $name -ErrorAction SilentlyContinue
if ($null -eq $existingValue) {
    # Create the registry value
    Write-Host "Adding '$name' registry value..."
    try {
        New-ItemProperty -Path $registryPath -Name $name -Value $value -PropertyType String -Force | Out-Null
        Write-Host "Registry value '$name' added successfully with value: $value"
    }
    catch {
        Write-Error "Failed to add registry value: $_"
        exit 1
    }
}
else {
    Write-Host "Registry value '$name' already exists with value: $($existingValue.$name)"
}

Write-Host "Script completed successfully."