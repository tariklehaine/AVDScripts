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

# Variabelen
$SubscriptionId = "2391ada8-feb5-4198-8876-abc31d30a5d5"
$ResourceGroup = "Desktops"
$SourceHostPool = "HP03"
$TargetHostPool = "HP04"
$AppNames = @("DIVERSE", "EXACT-PROD", "BEAUFORT", "IBS")

# Login en subscription selecteren
Connect-AzAccount
Set-AzContext -SubscriptionId $SubscriptionId

foreach ($App in $AppNames) {
    $SourceAppGroup = "$SourceHostPool-APP-$App"
    $TargetAppGroup = "$TargetHostPool-APP-$App"

    # Haal de resourceId van de app groups op
    $SourceAppGroupObj = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroup -Name $SourceAppGroup
    $TargetAppGroupObj = Get-AzWvdApplicationGroup -ResourceGroupName $ResourceGroup -Name $TargetAppGroup

    # Haal alle role assignments (gebruikers/groepen) op van de bron-appgroep
    $Assignments = Get-AzRoleAssignment -Scope $SourceAppGroupObj.Id | Where-Object { $_.RoleDefinitionName -eq "Desktop Virtualization User" }

    foreach ($Assignment in $Assignments) {
        # Controleer of de assignment al bestaat in de target app group
        $Exists = Get-AzRoleAssignment -Scope $TargetAppGroupObj.Id -ObjectId $Assignment.ObjectId -ErrorAction SilentlyContinue
        if (-not $Exists) {
            # Kopieer de assignment naar de target app group
            New-AzRoleAssignment -ObjectId $Assignment.ObjectId -RoleDefinitionName "Desktop Virtualization User" -Scope $TargetAppGroupObj.Id
            Write-Host "Assignment gekopieerd: $($Assignment.ObjectId) naar $TargetAppGroup"
        } else {
            Write-Host "Assignment bestaat al: $($Assignment.ObjectId) in $TargetAppGroup"
        }
    }
}