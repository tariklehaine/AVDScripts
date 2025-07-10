##########################################
Start-Sleep -Seconds 60

#verwijder huidige printer settings:
Remove-Item -Path 'HKCU:\Printers\DevModePerUser' -Force
#Remove-Item -Path 'HKCU:\Printers\DevModes2' -Force

# Disable "Let Windows manage my default printer" setting
try {
    $registryPathManageDefault = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows"
    Set-ItemProperty -Path $registryPathManageDefault -Name "LegacyDefaultPrinterMode" -Value 1 -Type DWord
    Write-Output "Disabled 'Let Windows manage my default printer' setting"
} catch {
    Write-Output "Error disabling 'Let Windows manage my default printer' setting: $_"
}

# Clear any existing default printer settings
try {
    $registryPathWindows = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows"
    Remove-ItemProperty -Path $registryPathWindows -Name "Device" -ErrorAction SilentlyContinue
    Write-Output "Cleared existing default printer settings"
} catch {
    Write-Output "Error clearing existing default printer settings: $_"
}

# Clear printer connections cache
try {
    $registryPathPrinterConnections = "HKCU:\Printers\Connections"
    if (Test-Path $registryPathPrinterConnections) {
        Remove-Item -Path "$registryPathPrinterConnections\*" -Recurse -Force -ErrorAction SilentlyContinue
        Write-Output "Cleared printer connections cache"
    }
} catch {
    Write-Output "Error clearing printer connections cache: $_"
}

#Maak de printer "Pameijer Printer Vertrouwelijk" aan
$PrinterName1 = "Pameijer Printer Vertrouwelijk"
$PrinterPortName = "NUL:"
$PrinterDriver = "Canon Generic Plus PCL6"

#Maak de printer "Pameijer Printer" aan
$PrinterName2 = "Pameijer Printer"
$PrinterPortName = "NUL:"
$PrinterDriver = "Canon Generic Plus PCL6"

#Zet de printer Driver voor "Pameijer Printer Vertrouwelijk" naar "Canon Generic Plus PCL6"
Get-Printer -Name "Pameijer Printer Vertrouwelijk" | Set-Printer -DriverName "Canon Generic Plus PCL6"

#Verander de default Driver van "uniFLOW Universal PclXL Driver" naar "Canon Generic Plus PCL6" voor Pameijer Printer
Get-Printer -Name "Pameijer Printer" | Set-Printer -DriverName "Canon Generic Plus PCL6"

#Add-Printer -Name $PrinterName2 -PortName $PrinterPortName -DriverName $PrinterDriver
Add-Printer -Name $PrinterName1 -PortName $PrinterPortName -DriverName $PrinterDriver

#Add-Printer -Name $PrinterName2 -PortName $PrinterPortName -DriverName $PrinterDriver
Add-Printer -Name $PrinterName2 -PortName $PrinterPortName -DriverName $PrinterDriver

#Importeer de Printer instellingen voor "Pameijer Printer Vertrouwelijk"
rundll32 printui.dll,PrintUIEntry /Sr /n "Pameijer Printer Vertrouwelijk" /a "C:\UniFlow\Pameijer_Printer_Vertrouwelijk.dat" g d r

#Importeer de Printer instellingen voor "Pameijer Printer"
rundll32 printui.dll,PrintUIEntry /Sr /n "Pameijer Printer" /a "C:\UniFlow\Pameijer_Printer.dat" g d r