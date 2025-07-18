# Requires Graph PowerShell SDK v1.0+
#   Install-Module Microsoft.Graph -Scope CurrentUser
# Permissions:
#   DeviceManagementManagedDevices.ReadWrite.All
#   DeviceManagementConfiguration.ReadWrite.All

# 1) Connect
Connect-MgGraph -Scopes "DeviceManagementManagedDevices.ReadWrite.All","DeviceManagementConfiguration.ReadWrite.All"

# 2) Define categories
$categoryName = "Pameijer - Unassigned"
$excludeCats  = @(
    "Windows - F-schijf Devices",
    "Windows - Pameijer Devices",
    "IOS - Pameijer Devices (Ipad / Iphone)",
    "macOS - Pameijer"
)

# Normalize exclude list to lowercase
$excludeLower = $excludeCats | ForEach-Object { $_.ToLowerInvariant() }

# 3) Lookup “Pameijer - Unassigned” category ID
$catResp = Invoke-MgGraphRequest -Method GET `
  -Uri "https://graph.microsoft.com/v1.0/deviceManagement/deviceCategories?`$filter=displayName eq '$categoryName'&`$select=id"
if ($catResp.value.Count -eq 0) {
    Write-Error "❌ Category '$categoryName' not found."
    exit
}
$categoryId = $catResp.value[0].id

# 4) Pull ALL managed devices with OS & category (handle paging)
$uri      = "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$select=id,deviceName,operatingSystem,deviceCategoryDisplayName"
$allDevs  = @()
$response = Invoke-MgGraphRequest -Method GET -Uri $uri
$allDevs += $response.value
while ($response.'@odata.nextLink') {
    $response  = Invoke-MgGraphRequest -Method GET -Uri $response.'@odata.nextLink'
    $allDevs  += $response.value
}

# 5) Locally filter:
#    - OS starts with "Windows"
#    - category is either empty or not in the exclude list (case‑insensitive)
$toAssign = $allDevs | Where-Object {
    $_.operatingSystem `
        -and $_.operatingSystem.StartsWith("Windows", [System.StringComparison]::InvariantCultureIgnoreCase) `
    -and (
        [string]::IsNullOrEmpty($_.deviceCategoryDisplayName) `
        -or ($excludeLower -notcontains $_.deviceCategoryDisplayName.ToLowerInvariant())
    )
}

if ($toAssign.Count -eq 0) {
    Write-Output "✅ No Windows devices outside the excluded categories were found. Nothing to do."
    exit
}

# 6) List which devices will be changed
Write-Output "The following Windows devices will be set to '$categoryName':"
$toAssign | ForEach-Object {
    $current = if ([string]::IsNullOrEmpty($_.deviceCategoryDisplayName)) { "<none>" } else { $_.deviceCategoryDisplayName }
    Write-Output "  - $($_.deviceName) (Current: $current; OS: $($_.operatingSystem))"
}

# 7) Confirm before applying
$response = Read-Host "`nProceed to assign '$categoryName' to these $($toAssign.Count) device(s)? (Y/N)"
if ($response -notmatch '^[Yy]') {
    Write-Output "❌ Aborted. No changes made."
    exit
}

# 8) Assign the category via the $ref endpoint
foreach ($d in $toAssign) {
    Write-Output "➡️ Assigning '$categoryName' to $($d.deviceName)…"
    $refUri  = "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$($d.id)/deviceCategory/`$ref"
    $refBody = @{ "@odata.id" = "https://graph.microsoft.com/beta/deviceManagement/deviceCategories/$categoryId" } | ConvertTo-Json

    Invoke-MgGraphRequest -Method PUT -Uri $refUri -Body $refBody
    Write-Output "   ✅ Done."
}

Write-Output "`n🎉 Finished: assigned '$categoryName' to $($toAssign.Count) device(s)."
