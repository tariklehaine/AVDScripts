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

# 1. Sign in and select subscription
Connect-AzAccount
Set-AzContext -SubscriptionId '2391ada8-feb5-4198-8876-abc31d30a5d5'

# 2. Define parameters
$userGroupId        = '41f295a7-0e00-4d2c-bbe0-084fd6aa2f66'
$resourceGroupName  = 'DESKTOPS'
$hostPoolName       = 'HP04'
$roleDefinitionName = 'Desktop Virtualization User'

# 3. (Ensure Az.DesktopVirtualization module is available)
if (-not (Get-Module -ListAvailable -Name Az.DesktopVirtualization)) {
    Install-Module Az.DesktopVirtualization -Scope CurrentUser -Force
}
Import-Module Az.DesktopVirtualization

# 4. Get all application groups in the host pool
$appGroups = Get-AzDesktopVirtualizationApplicationGroup `
    -ResourceGroupName $resourceGroupName `
    -HostPoolName      $hostPoolName

# 5. Loop and assign
foreach ($ag in $appGroups) {
    Write-Host "Assigning group to Application Group: $($ag.Name)"
    New-AzRoleAssignment `
        -ObjectId          $userGroupId `
        -RoleDefinitionName $roleDefinitionName `
        -Scope             $ag.Id
}
