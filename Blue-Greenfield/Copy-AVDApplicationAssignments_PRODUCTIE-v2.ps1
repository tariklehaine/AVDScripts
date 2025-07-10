# Vereiste modules controleren en installeren indien nodig
$RequiredModules = @("Az.Accounts", "Az.DesktopVirtualization")

foreach ($Module in $RequiredModules) {
    if (Get-Module -ListAvailable -Name $Module) {
        Write-Host "Module $Module is al geinstalleerd" -ForegroundColor Green
    } else {
        Write-Host "Installeren van module $Module..." -ForegroundColor Yellow
        Install-Module -Name $Module -Force
    }
    
    # Importeer de module als deze nog niet geladen is
    if (!(Get-Module -Name $Module)) {
        Write-Host "Importeren van module $Module..." -ForegroundColor Cyan
        Import-Module $Module
    } else {
        Write-Host "Module $Module is al geimporteerd" -ForegroundColor Green
    }
}

# Gebruikersinvoer voor Host Pools
Write-Host "`n=== AVD Application Assignment Copy Tool ===" -ForegroundColor Cyan
Write-Host "Dit script kopieert applicatie-assignments tussen AVD Host Pools`n" -ForegroundColor White

$SourceHostPool = Read-Host "Voer de naam in van de bron Host Pool waar de assigments van gekopieerd moeten worden"
$TargetHostPool = Read-Host "Voer de naam in van de doel Host Pool waar de assigments naartoe moeten"

# Validatie van invoer
if ([string]::IsNullOrWhiteSpace($SourceHostPool)) {
    Write-Host "Fout: Bron Host Pool naam is verplicht!" -ForegroundColor Red
    exit 1
}

if ([string]::IsNullOrWhiteSpace($TargetHostPool)) {
    Write-Host "Fout: Doel Host Pool naam is verplicht!" -ForegroundColor Red
    exit 1
}

# Bevestiging van configuratie
Write-Host "`n=== Configuratie Overzicht ===" -ForegroundColor Yellow
Write-Host "Van welke Host Pool moeten de assigments gekopieerd worden: $SourceHostPool" -ForegroundColor Green
Write-Host "Doel Host Pool (Acceptatie): $TargetHostPool" -ForegroundColor Green
Write-Host "Applicaties: DIVERSE, EXACT-PROD, BEAUFORT, IBS`n" -ForegroundColor Green

$Confirm = Read-Host "Wilt u doorgaan met het kopiëren van assignments? (j/n)"
if ($Confirm -notmatch "^[jJ]") {
    Write-Host "Script afgebroken door gebruiker." -ForegroundColor Yellow
    exit 0
}

# Variabelen
$SubscriptionId = "2391ada8-feb5-4198-8876-abc31d30a5d5"
$ResourceGroup = "Desktops"
$AppNames = @("DIVERSE", "EXACT-PROD", "BEAUFORT", "IBS")

# Login en subscription selecteren
Write-Host "`nInloggen bij Azure..." -ForegroundColor Cyan
Connect-AzAccount
Set-AzContext -SubscriptionId $SubscriptionId

Write-Host "`nStarten met kopiëren van assignments..." -ForegroundColor Cyan

foreach ($App in $AppNames) {
    $SourceAppGroup = "$SourceHostPool-APP-$App"
    $TargetAppGroup = "$TargetHostPool-APP-$App"

    Write-Host "`nVerwerken van applicatie: $App" -ForegroundColor Yellow
    Write-Host "Bron: $SourceAppGroup" -ForegroundColor Gray
    Write-Host "Doel: $TargetAppGroup" -ForegroundColor Gray

    try {
        # Haal de resourceId van de app groups op
        $SourceAppGroupObj = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroup -Name $SourceAppGroup -ErrorAction Stop
        $TargetAppGroupObj = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroup -Name $TargetAppGroup -ErrorAction Stop

        # Haal alle role assignments (gebruikers/groepen) op van de bron-appgroep
        $Assignments = Get-AzRoleAssignment -Scope $SourceAppGroupObj.Id | Where-Object { $_.RoleDefinitionName -eq "Desktop Virtualization User" }

        if ($Assignments.Count -eq 0) {
            Write-Host "Geen assignments gevonden in $SourceAppGroup" -ForegroundColor Yellow
            continue
        }

        Write-Host "Gevonden $($Assignments.Count) assignment(s) in $SourceAppGroup" -ForegroundColor Green

        foreach ($Assignment in $Assignments) {
            # Controleer of de assignment al bestaat in de target app group
            $Exists = Get-AzRoleAssignment -Scope $TargetAppGroupObj.Id -ObjectId $Assignment.ObjectId -ErrorAction SilentlyContinue
            if (-not $Exists) {
                # Kopieer de assignment naar de target app group
                New-AzRoleAssignment -ObjectId $Assignment.ObjectId -RoleDefinitionName "Desktop Virtualization User" -Scope $TargetAppGroupObj.Id
                Write-Host "✓ Assignment gekopieerd: $($Assignment.DisplayName) ($($Assignment.ObjectId)) naar $TargetAppGroup" -ForegroundColor Green
            } else {
                Write-Host "- Assignment bestaat al: $($Assignment.DisplayName) ($($Assignment.ObjectId)) in $TargetAppGroup" -ForegroundColor Yellow
            }
        }
    }
    catch {
        Write-Host "✗ Fout bij verwerken van $App`: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== Kopiëren voltooid ===" -ForegroundColor Cyan
Write-Host "Alle assignments zijn verwerkt." -ForegroundColor Green