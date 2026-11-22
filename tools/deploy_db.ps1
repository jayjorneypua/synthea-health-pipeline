# deploys the SyntheaHealth database. -Reset drops it first for a clean slate.
param([switch]$Reset)

[string]$Root = Split-Path -Parent $PSScriptRoot
[string]$Server = "."
[string]$Database = "SyntheaHealth"

if ($Reset) {
  Write-Host "dropping $Database..."
  sqlcmd -S $Server -E -C -b -Q "IF DB_ID(N'$Database') IS NOT NULL BEGIN ALTER DATABASE [$Database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE; DROP DATABASE [$Database]; END"
  if ($LASTEXITCODE -ne 0) { throw "reset failed" }
}

sqlcmd -S $Server -E -C -b -I -i (Join-Path $Root "db\00_create_database.sql")
if ($LASTEXITCODE -ne 0) { throw "create database failed" }

[string[]]$Files = @(
  "db\01_schemas.sql"
, "db\tables\security.User.sql"
, "db\tables\ref.Location.sql"
, "db\procs\ref.spLocation_UpdateHierarchy.sql"
, "db\tables\ref.Code.sql"
, "db\tables\ref.Payer.sql"
, "db\tables\ref.Organization.sql"
, "db\tables\ref.Provider.sql"
, "db\tables\clinical.Patient.sql"
, "db\tables\clinical.Encounter.sql"
, "db\tables\clinical.Condition.sql"
, "db\tables\clinical.Medication.sql"
, "db\tables\clinical.Procedure.sql"
)

foreach ($File in $Files) {
  Write-Host "deploying $File"
  sqlcmd -S $Server -E -C -b -I -d $Database -i (Join-Path $Root $File)
  if ($LASTEXITCODE -ne 0) { throw "failed: $File" }
}

Write-Host "deploy done" -ForegroundColor Green