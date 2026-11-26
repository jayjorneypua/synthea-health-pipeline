# wipes the Databricks side for a clean rerun: drops and recreates bronze, silver, gold, omop
# (tables, dbt marts, FHIR tables) and the landing cdc and fhir volumes (files and Auto Loader checkpoints).
# names and comments match resources/synthea.schemas.yml so the bundle stays in sync.
[string]$Profile = "dbc-609647e1-c073"
[string]$WarehouseId = "606b0c60dc21c8fd"

[string[]]$Statements = @(
  "DROP SCHEMA IF EXISTS synthea.omop CASCADE"
, "DROP SCHEMA IF EXISTS synthea.gold CASCADE"
, "DROP SCHEMA IF EXISTS synthea.silver CASCADE"
, "DROP SCHEMA IF EXISTS synthea.bronze CASCADE"
, "DROP VOLUME IF EXISTS synthea.landing.cdc"
, "DROP VOLUME IF EXISTS synthea.landing.fhir"
, "CREATE SCHEMA synthea.bronze COMMENT 'Auto Loader tables, one per capture instance plus raw FHIR bundles'"
, "CREATE SCHEMA synthea.silver COMMENT 'CDC applied, deduped, SCD2 patients; flattened and de-identified FHIR'"
, "CREATE SCHEMA synthea.gold COMMENT 'dbt marts and FHIR metrics for Power BI'"
, "CREATE SCHEMA synthea.omop COMMENT 'OMOP CDM v5.4 tables built from the FHIR source'"
, "CREATE VOLUME synthea.landing.cdc COMMENT 'CDC Parquet files, one folder per capture instance'"
, "CREATE VOLUME synthea.landing.fhir COMMENT 'Synthea FHIR R4 bundles, one JSON file per patient'"
)

[string]$TempFile = Join-Path $env:TEMP "reset_databricks.json"

foreach ($Statement in $Statements) {
  Write-Host "running: $Statement"
  # body in a temp file: PowerShell 5.1 strips quotes from JSON passed to native commands
  [string]$Body = @{ warehouse_id = $WarehouseId; statement = $Statement; wait_timeout = "50s" } | ConvertTo-Json -Compress
  [System.IO.File]::WriteAllText($TempFile, $Body, (New-Object System.Text.UTF8Encoding($false)))
  [string]$Response = databricks api post /api/2.0/sql/statements --json "@$TempFile" --profile $Profile | Out-String
  [PSCustomObject]$Result = $Response | ConvertFrom-Json
  if ($Result.status.state -ne "SUCCEEDED") {
    Remove-Item $TempFile
    throw "failed: $Statement`n$Response"
  }
}

Remove-Item $TempFile
Write-Host "databricks reset done" -ForegroundColor Green