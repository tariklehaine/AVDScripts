# Script to import W. Europe Standard Time registry settings
# For deployment via Intune to Azure Virtual Desktop hosts

# Set execution policy to allow script to run
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction Stop
    Write-Output "Execution policy set to Bypass for current process."
} 
catch {
    Write-Error "Failed to set execution policy: $_"
}

# Create a temporary directory to store the registry file
$tempDir = "$env:TEMP\TimeZoneSettings"
if (-not (Test-Path -Path $tempDir)) {
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    Write-Output "Created temporary directory: $tempDir"
}

# Create the registry file content
$regContent = @"
Windows Registry Editor Version 5.00

[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\TimeZoneInformation]
"Bias"=dword:ffffffc4
"DaylightBias"=dword:ffffffc4
"DaylightName"="@tzres.dll,-321"
"DaylightStart"=hex:00,00,03,00,05,00,02,00,00,00,00,00,00,00,00,00
"StandardBias"=dword:00000000
"StandardName"="@tzres.dll,-322"
"StandardStart"=hex:00,00,0a,00,05,00,03,00,00,00,00,00,00,00,00,00
"TimeZoneKeyName"="W. Europe Standard Time"
"DynamicDaylightTimeDisabled"=dword:00000000
"ActiveTimeBias"=dword:ffffff88
"@

# Save the registry content to a file
$regFilePath = "$tempDir\timezone.reg"
$regContent | Out-File -FilePath $regFilePath -Encoding unicode -Force
Write-Output "Registry file created at: $regFilePath"

# Import the registry file
try {
    Start-Process -FilePath "regedit.exe" -ArgumentList "/s", "`"$regFilePath`"" -Wait -NoNewWindow -ErrorAction Stop
    Write-Output "Registry settings imported successfully."
} 
catch {
    Write-Error "Failed to import registry settings: $_"
}

# Alternative method using reg.exe in case regedit fails
if (-not $?) {
    try {
        $regExitCode = (Start-Process -FilePath "reg.exe" -ArgumentList "import", "`"$regFilePath`"" -Wait -NoNewWindow -PassThru).ExitCode
        if ($regExitCode -eq 0) {
            Write-Output "Registry imported using reg.exe successfully."
        } else {
            Write-Error "reg.exe import failed with exit code: $regExitCode"
        }
    }
    catch {
        Write-Error "Failed to import using reg.exe: $_"
    }
}

# Set time zone using PowerShell directly as a fallback method
try {
    Set-TimeZone -Id "W. Europe Standard Time" -ErrorAction Stop
    Write-Output "Time zone set directly using PowerShell."
}
catch {
    Write-Warning "Could not set time zone directly: $_"
}

# Cleanup
Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Output "Temporary directory removed."

# Log completion
$logPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
if (-not (Test-Path -Path $logPath)) {
    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
}
"$(Get-Date) - Time zone configuration completed" | Out-File -FilePath "$logPath\TimeZoneConfig.log" -Append

Exit 0
