#Dit script maakt de printers aan voor de Uniflow printer mapping in AVD
#verwijderd de printers als ze bestaan

$printers = ("Pameijer Printer", "Pameijer Printer Vertrouwelijk")
foreach ($printer in $printers) {

    try {

        Remove-Printer -Name $printer

    } catch {

        Write-Host -Message $_.Exception.message

    }

}
#Maak de printer "Pameijer Printer Vertrouwelijk" aan

$PrinterName = "Pameijer Printer Vertrouwelijk"
$PrinterPortName = "NUL:"
$PrinterDriver = "Canon Generic Plus PCL6"

Add-Printer -Name $PrinterName -PortName $PrinterPortName -DriverName $PrinterDriver

#Maak de printer "Pameijer Printer" aan
$PrinterName = "Pameijer Printer"
$PrinterPortName = "NUL:"
$PrinterDriver = "Canon Generic Plus PCL6"

Add-Printer -Name $PrinterName -PortName $PrinterPortName -DriverName $PrinterDriver

#Importeer de Printer instellingen voor "Pameijer Printer Vertrouwelijk"
rundll32 printui.dll,PrintUIEntry /Sr /n "Pameijer Printer Vertrouwelijk" /a "C:\UniFlow\Pameijer_Printer_Vertrouwelijk.dat" g d r

#Importeer de Printer instellingen voor "Pameijer Printer"
rundll32 printui.dll,PrintUIEntry /Sr /n "Pameijer Printer" /a "C:\UniFlow\Pameijer_Printer.dat" g d r

#Default Printer zetten
$printer = Get-CimInstance -Class Win32_Printer -Filter "Name='Pameijer Printer'"
Invoke-CimMethod -InputObject $printer -MethodName SetDefaultPrinter