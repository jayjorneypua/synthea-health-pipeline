# runs one SQL statement on the Databricks warehouse and prints the result as tab-separated rows.
# usage: .\tools\dbsql.ps1 "SELECT count(*) FROM synthea.bronze.clinical_patient"
param([Parameter(Mandatory = $true)][string]$Sql)

[string]$Profile = "dbc-609647e1-c073"
[string]$WarehouseId = "606b0c60dc21c8fd"

# request body in a temp file: PowerShell 5.1 strips quotes from JSON passed to native commands
[string]$Body = @{ warehouse_id = $WarehouseId; statement = $Sql; wait_timeout = "50s" } | ConvertTo-Json
[string]$TempFile = Join-Path $env:TEMP "dbsql_statement.json"
[System.IO.File]::WriteAllText($TempFile, $Body, (New-Object System.Text.UTF8Encoding($false)))

[string]$Raw = (databricks api post /api/2.0/sql/statements --json "@$TempFile" --profile $Profile) -join "`n"
Remove-Item $TempFile
$Result = $Raw | ConvertFrom-Json

if ($Result.status.state -ne "SUCCEEDED") {
  throw ("statement " + $Result.status.state + ": " + $Result.status.error.message)
}

Write-Host (($Result.manifest.schema.columns | ForEach-Object { $_.name }) -join "`t")
foreach ($Row in $Result.result.data_array) {
  Write-Host ($Row -join "`t")
}