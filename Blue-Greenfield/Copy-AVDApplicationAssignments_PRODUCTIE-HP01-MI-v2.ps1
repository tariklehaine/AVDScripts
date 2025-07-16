# AVD Application Assignment Copy Tool - Azure Automation Version (Corrected)
# Script voor het kopiëren van applicatie-assignments tussen AVD Host Pools

# Vereiste modules controleren (voor Azure Automation moeten deze vooraf geïnstalleerd zijn)
$RequiredModules = @("Az.Accounts", "Az.DesktopVirtualization", "Az.Resources")

foreach ($Module in $RequiredModules) {
    try {
        # Probeer module te importeren
        if (!(Get-Module -Name $Module)) {
            Write-Output "Importeren van module $Module..."
            Import-Module $Module -ErrorAction Stop
        } else {
            Write-Output "Module $Module is al geimporteerd"
        }
    } catch {
        Write-Error "Module $Module kon niet worden geïmporteerd: $($_.Exception.Message)"
        Write-Error "Zorg ervoor dat alle benodigde modules zijn geïnstalleerd in Azure Automation"
        exit 1
    }
}

# Statische configuratie
$SourceHostPool = "HP02"
$TargetHostPool = "HP01"
$SubscriptionId = "2391ada8-feb5-4198-8876-abc31d30a5d5"
$ResourceGroup = "Desktops"
$AppNames = @("DIVERSE", "EXACT-PROD", "BEAUFORT", "IBS", "BEHEER05", "CLIENTELE-ITSM-2023", "CLOUD-DRIVE-MAPPER", "MICROSOFT-EDGE", "OFFICE365", "ORTEC-PROD", "ORTEC-TEST", "PLANCARE-DOSSIER", "PLANCARE2", "RDP-APPS147", "RDP-APPS170", "RDP-APPS33", "RDP-APPS69", "RDP-AZ-BEHEER01", "RDP-BEAUFORT", "RDP-BEHEER07", "RDP-EXACT-SERVERS", "RDP-IBS-SERVERS", "RDP-ITSM", "RDP-OMADA", "RDP-ORTEC-SERVERS", "RDP-SQLC09", "RDP-SQLC10", "YOUFORCE-PROFESSIONAL")

Write-Output "=== AVD Application Assignment Copy Tool - Automation Version ==="
Write-Output "Kopiëren van applicatie-assignments tussen AVD Host Pools"

# Authenticatie via Managed Identity
Write-Output "Authenticeren via Managed Identity..."
try {
    Connect-AzAccount -Identity -ErrorAction Stop | Out-Null
    Write-Output "Succesvol ingelogd met Managed Identity"
} catch {
    Write-Error "Fout bij authenticatie met Managed Identity: $($_.Exception.Message)"
    exit 1
}

# Subscription context instellen
try {
    Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop
    Write-Output "Subscription context ingesteld: $SubscriptionId"
} catch {
    Write-Error "Fout bij instellen subscription context: $($_.Exception.Message)"
    exit 1
}

# Validatie van host pools
Write-Output "Valideren van host pools..."
try {
    Get-AzWvdHostPool -ResourceGroupName $ResourceGroup -Name $SourceHostPool -ErrorAction Stop | Out-Null
    Get-AzWvdHostPool -ResourceGroupName $ResourceGroup -Name $TargetHostPool -ErrorAction Stop | Out-Null
    Write-Output "✓ Beide host pools gevonden en toegankelijk"
} catch {
    Write-Error "Fout bij valideren host pools: $($_.Exception.Message)"
    exit 1
}

# Configuratie overzicht
Write-Output "=== Configuratie Overzicht ==="
Write-Output "Bron Host Pool: $SourceHostPool"
Write-Output "Doel Host Pool: $TargetHostPool"
Write-Output "Resource Group: $ResourceGroup"
Write-Output "Aantal applicaties: $($AppNames.Count)"

# Starten met kopiëren van assignments
Write-Output "Starten met kopiëren van assignments..."
$SuccessCount = 0
$ErrorCount = 0
$SkippedCount = 0

foreach ($App in $AppNames) {
    $SourceAppGroup = "$SourceHostPool-APP-$App"
    $TargetAppGroup = "$TargetHostPool-APP-$App"
    
    Write-Output "Verwerken van applicatie: $App"
    Write-Output "Bron: $SourceAppGroup"
    Write-Output "Doel: $TargetAppGroup"
    
    try {
        # Haal de resourceId van de app groups op
        $SourceAppGroupObj = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroup -Name $SourceAppGroup -ErrorAction Stop
        $TargetAppGroupObj = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroup -Name $TargetAppGroup -ErrorAction Stop
        
        # Haal alle role assignments (gebruikers/groepen) op van de bron-appgroep
        $Assignments = Get-AzRoleAssignment -Scope $SourceAppGroupObj.Id | Where-Object { $_.RoleDefinitionName -eq "Desktop Virtualization User" }
        
        if (-not $Assignments -or @($Assignments).Count -eq 0) {
            Write-Output "Geen assignments gevonden in $SourceAppGroup"
            $SkippedCount++
            continue
        }
        
        Write-Output "Gevonden $(@($Assignments).Count) assignment(s) in $SourceAppGroup"
        
        $CopiedCount = 0
        $AlreadyExistsCount = 0
        
        foreach ($Assignment in $Assignments) {
            try {
                # Controleer of de assignment al bestaat in de target app group
                $ExistingAssignment = Get-AzRoleAssignment -Scope $TargetAppGroupObj.Id -ObjectId $Assignment.ObjectId -RoleDefinitionName "Desktop Virtualization User" -ErrorAction SilentlyContinue
                
                if (-not $ExistingAssignment) {
                    # Kopieer de assignment naar de target app group
                    New-AzRoleAssignment -ObjectId $Assignment.ObjectId -RoleDefinitionName "Desktop Virtualization User" -Scope $TargetAppGroupObj.Id -ErrorAction Stop
                    Write-Output "✓ Assignment gekopieerd: $($Assignment.DisplayName) ($($Assignment.ObjectId)) naar $TargetAppGroup"
                    $CopiedCount++
                } else {
                    Write-Output "- Assignment bestaat al: $($Assignment.DisplayName) ($($Assignment.ObjectId)) in $TargetAppGroup"
                    $AlreadyExistsCount++
                }
            } catch {
                Write-Error "Fout bij kopiëren assignment $($Assignment.DisplayName): $($_.Exception.Message)"
                # Continue met volgende assignment
            }
        }
        
        Write-Output "App $App`: $CopiedCount gekopieerd, $AlreadyExistsCount bestonden al"
        $SuccessCount++
        
    } catch [Microsoft.Azure.PowerShell.Cmdlets.DesktopVirtualization.Runtime.RestException] {
        if ($_.Exception.Message -like "*ResourceNotFound*") {
            Write-Warning "⚠ Application group niet gevonden: $SourceAppGroup of $TargetAppGroup"
            $SkippedCount++
        } else {
            Write-Error "✗ Fout bij verwerken van $App`: $($_.Exception.Message)"
            $ErrorCount++
        }
    } catch {
        Write-Error "✗ Fout bij verwerken van $App`: $($_.Exception.Message)"
        $ErrorCount++
    }
}

# Samenvatting
Write-Output "=== Kopiëren voltooid ==="
Write-Output "Succesvol verwerkt: $SuccessCount applicaties"
Write-Output "Overgeslagen (geen assignments of niet gevonden): $SkippedCount applicaties"
Write-Output "Fouten opgetreden: $ErrorCount applicaties"
Write-Output "Alle assignments zijn verwerkt."

# Return status voor monitoring
if ($ErrorCount -eq 0) {
    Write-Output "Script succesvol afgerond zonder fouten"
    exit 0
} else {
    Write-Output "Script afgerond met $ErrorCount fouten"
    exit 1
}