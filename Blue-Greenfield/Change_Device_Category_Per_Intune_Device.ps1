# Requires Graph PowerShell SDK v1.0+ 
# Install-Module Microsoft.Graph -Scope CurrentUser
# Permissions needed:
#   DeviceManagementManagedDevices.ReadWrite.All, DeviceManagementConfiguration.ReadWrite.All

# 1) Connect
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All","DeviceManagementConfiguration.ReadWrite.All"

# 2) Define names
$categoryName = "Pameijer - Unassigned"
$deviceName   = "3085DT39-03"

# 3) Get the Device Category ID (v1.0 read)
$catUri  = "https://graph.microsoft.com/v1.0/deviceManagement/deviceCategories?`$filter=displayName eq '$categoryName'&`$select=id"
$catResp = Invoke-MgGraphRequest -Method GET -Uri $catUri
if ($catResp.value.Count -eq 0) {
    Write-Error "❌ Category '$categoryName' not found."
    exit
}
$categoryId = $catResp.value[0].id

# 4) Get the Managed Device (v1.0 read)
$devUri  = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$filter=deviceName eq '$deviceName'&`$select=id,deviceCategoryDisplayName"
$devResp = Invoke-MgGraphRequest -Method GET -Uri $devUri
if ($devResp.value.Count -eq 0) {
    Write-Error "❌ Managed device '$deviceName' not found."
    exit
}
$device      = $devResp.value[0]
$currentCat  = $device.deviceCategoryDisplayName

# 5) Prompt for confirmation
if ([string]::IsNullOrEmpty($currentCat)) {
    $prompt = "Device '$deviceName' has no category. Assign '$categoryName'? (Y/N)"
}
else {
    $prompt = "Device '$deviceName' currently has category '$currentCat'. Change it to '$categoryName'? (Y/N)"
}
$response = Read-Host $prompt

if ($response -match '^[Yy]') {
    Write-Output "Applying category..."
    # 6) PUT to the $ref endpoint to assign the category
    $refUri  = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($device.id)/deviceCategory/`$ref"
    $refBody = @{ "@odata.id" = "https://graph.microsoft.com/beta/deviceManagement/deviceCategories/$categoryId" } | ConvertTo-Json

    Invoke-MgGraphRequest -Method PUT -Uri $refUri -Body $refBody

    Write-Output "✅ Category set to '$categoryName' for device '$deviceName'."
}
else {
    Write-Output "No changes made to device '$deviceName'."
}
