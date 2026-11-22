# one-time Databricks setup: creates the synthea catalog (bundles cannot create catalogs).
# Free Edition blocks the catalogs API (Default Storage), so it runs CREATE CATALOG as SQL
# on the warehouse. schemas, the landing volume and the job are in the bundle.
[string]$Profile = "dbc-609647e1-c073"
[string]$Catalog = "synthea"
[string]$WarehouseId = "606b0c60dc21c8fd"

databricks catalogs get $Catalog --profile $Profile *> $null
if ($LASTEXITCODE -eq 0) {
  Write-Host "catalog $Catalog already exists"
  return
}

# request body in a temp file: PowerShell 5.1 strips quotes from JSON passed to native commands
[string]$Body = '{"warehouse_id":"' + $WarehouseId + '","statement":"CREATE CATALOG IF NOT EXISTS ' + $Catalog + ' COMMENT ''Synthea health pipeline''","wait_timeout":"50s"}'
[string]$TempFile = Join-Path $env:TEMP "create_catalog.json"
[System.IO.File]::WriteAllText($TempFile, $Body, (New-Object System.Text.UTF8Encoding($false)))

databricks api post /api/2.0/sql/statements --json "@$TempFile" --profile $Profile
Remove-Item $TempFile

databricks catalogs get $Catalog --profile $Profile *> $null
if ($LASTEXITCODE -ne 0) { throw "catalog $Catalog was not created, check the statement output above" }
Write-Host "catalog $Catalog created" -ForegroundColor Green