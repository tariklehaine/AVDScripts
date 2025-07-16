a# Vereiste modules controleren en installeren indien nodig
$RequiredModules = @("Az.Accounts", "Az.DesktopVirtualization")

foreach ($Module in $RequiredModules) {
    if (Get-Module -ListAvailable -Name $Module) {
        Write-Host "Module $Module is al geïnstalleerd" -ForegroundColor Green
    } else {
        Write-Host "Installeren van module $Module..." -ForegroundColor Yellow
        Install-Module -Name $Module -Force
    }
    
    # Importeer de module als deze nog niet geladen is
    if (!(Get-Module -Name $Module)) {
        Write-Host "Importeren van module $Module..." -ForegroundColor Cyan
        Import-Module $Module
    } else {
        Write-Host "Module $Module is al geïmporteerd" -ForegroundColor Green
    }
}

# Variabelen
$SubscriptionId = "2391ada8-feb5-4198-8876-abc31d30a5d5"
$ResourceGroup = "Desktops"
$SourceHostPool = "HP04"  # Statische waarde in plaats van Read-Host
$AppNames = @("DIVERSE", "EXACT-PROD", "BEAUFORT", "IBS", "BEHEER05", "CLIENTELE-ITSM-2023", "CLIENTELE-ITSM-2023", "CLOUD-DRIVE-MAPPER", "MICROSOFT-EDGE", "OFFICE365", "ORTEC-PROD", "ORTEC-TEST", "PLANCARE-DOSSIER", "PLANCARE2", "RDP-APPS147", "RDP-APPS170", "RDP-APPS33", "RDP-APPS69", "RDP-AZ-BEHEER01", "RDP-BEAUFORT", "RDP-BEHEER07", "RDP-EXACT-SERVERS", "RDP-IBS-SERVERS", "RDP-ITSM", "RDP-OMADA", "RDP-ORTEC-SERVERS", "RDP-SQLC09", "RDP-SQLC10", "YOUFORCE-PROFESSIONAL")

# Login met managed identity en subscription selecteren
try {
    Write-Host "Verbinden met Azure via Managed Identity..." -ForegroundColor Cyan
    Connect-AzAccount -Identity
    Set-AzContext -SubscriptionId $SubscriptionId
    Write-Host "Succesvol verbonden met Azure" -ForegroundColor Green
} catch {
    Write-Host "Fout bij verbinden met Azure: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

foreach ($App in $AppNames) {
    $SourceAppGroup = "$SourceHostPool-APP-$App"
    Write-Host "Verwerken van app group: $SourceAppGroup" -ForegroundColor Yellow
    
    # Haal de resourceId van de source app group op
    $SourceAppGroupObj = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroup -Name $SourceAppGroup
    
    if ($SourceAppGroupObj) {
        # Haal alle role assignments (gebruikers/groepen) op van de bron-appgroep
        $Assignments = Get-AzRoleAssignment -Scope $SourceAppGroupObj.Id | Where-Object { $_.RoleDefinitionName -eq "Desktop Virtualization User" }
        
        if ($Assignments.Count -gt 0) {
            Write-Host "Gevonden $($Assignments.Count) assignment(s) in $SourceAppGroup" -ForegroundColor Green
            
            foreach ($Assignment in $Assignments) {
                try {
                    # Verwijder de assignment van de source app group
                    Remove-AzRoleAssignment -ObjectId $Assignment.ObjectId -RoleDefinitionName "Desktop Virtualization User" -Scope $SourceAppGroupObj.Id -Confirm:$false
                    Write-Host "Assignment verwijderd: $($Assignment.DisplayName) ($($Assignment.ObjectId)) van $SourceAppGroup" -ForegroundColor Green
                } catch {
                    Write-Host "Fout bij verwijderen assignment $($Assignment.ObjectId) van $SourceAppGroup : $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "Geen assignments gevonden in $SourceAppGroup" -ForegroundColor Gray
        }
    } else {
        Write-Host "App group $SourceAppGroup niet gevonden!" -ForegroundColor Red
    }
    
    Write-Host "---" -ForegroundColor Gray
}

Write-Host "Script voltooid" -ForegroundColor Green
