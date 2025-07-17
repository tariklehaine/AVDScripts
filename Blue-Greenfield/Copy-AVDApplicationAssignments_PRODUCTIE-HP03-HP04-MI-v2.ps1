# Vereiste modules controleren en installeren indien nodig
$RequiredModules = @("Az.Accounts", "Az.DesktopVirtualization")

foreach ($Module in $RequiredModules) {
    if (Get-Module -ListAvailable -Name $Module) {
        Write-Output "Module $Module is al geinstalleerd"
    } else {
        Write-Output "Installeren van module $Module..."
        Install-Module -Name $Module -Force -Scope CurrentUser
    }
    
    # Importeer de module als deze nog niet geladen is
    if (!(Get-Module -Name $Module)) {
        Write-Output "Importeren van module $Module..."
        Import-Module $Module
    } else {
        Write-Output "Module $Module is al geimporteerd"
    }
}

# Statische configuratie
$SourceHostPool = "HP01"
$TargetHostPool = "HP02"
$SubscriptionId = "2391ada8-feb5-4198-8876-abc31d30a5d5"
$ResourceGroup = "Desktops"
$AppNames = @("DIVERSE", "EXACT-PROD", "BEAUFORT", "IBS")

# Authenticatie via Managed Identity
try {
    Write-Output "Authenticating using Managed Identity..."
    Connect-AzAccount -Identity
    Set-AzContext -SubscriptionId $SubscriptionId
    Write-Output "Successfully authenticated with Managed Identity"
} catch {
    Write-Error "Failed to authenticate with Managed Identity: $($_.Exception.Message)"
    throw
}

# Configuratie overzicht
Write-Output "=== Configuratie Overzicht ==="
Write-Output "Host Pool waar assignments van gekopieerd worden: $SourceHostPool"
Write-Output "Host Pool waar assignments naar gekopieerd worden: $TargetHostPool"
Write-Output "Aantal applicaties: $($AppNames.Count)"

Write-Output "Starten met kopiëren van assignments..."

$SuccessCount = 0
$ErrorCount = 0

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
        
        if ($Assignments.Count -eq 0) {
            Write-Output "Geen assignments gevonden in $SourceAppGroup"
            continue
        }
        
        Write-Output "Gevonden $($Assignments.Count) assignment(s) in $SourceAppGroup"
        
        foreach ($Assignment in $Assignments) {
            # Controleer of de assignment al bestaat in de target app group
            $Exists = Get-AzRoleAssignment -Scope $TargetAppGroupObj.Id -ObjectId $Assignment.ObjectId -ErrorAction SilentlyContinue
            
            if (-not $Exists) {
                # Kopieer de assignment naar de target app group
                New-AzRoleAssignment -ObjectId $Assignment.ObjectId -RoleDefinitionName "Desktop Virtualization User" -Scope $TargetAppGroupObj.Id
                Write-Output "✓ Assignment gekopieerd: $($Assignment.DisplayName) ($($Assignment.ObjectId)) naar $TargetAppGroup"
            } else {
                Write-Output "- Assignment bestaat al: $($Assignment.DisplayName) ($($Assignment.ObjectId)) in $TargetAppGroup"
            }
        }
        
        $SuccessCount++
        
    } catch {
        Write-Error "✗ Fout bij verwerken van $App`: $($_.Exception.Message)"
        $ErrorCount++
    }
}

Write-Output "=== Kopiëren voltooid ==="
Write-Output "Succesvol verwerkt: $SuccessCount applicaties"
Write-Output "Fouten: $ErrorCount applicaties"