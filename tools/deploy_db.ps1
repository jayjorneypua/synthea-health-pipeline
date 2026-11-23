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
, "db\tables\clinical.Claim.sql"
, "db\tables\clinical.ClaimLine.sql"
, "db\tables\stage.Tables.sql"
, "db\tables\ref.UsState.sql"
, "db\procs\ref.spLocation_RebuildHierarchy.sql"
, "db\procs\stage.spMerge_Location.sql"
, "db\procs\stage.spMerge_Code.sql"
, "db\views\stage.vwCityLookup.sql"
, "db\procs\stage.spMerge_Payer.sql"
, "db\procs\stage.spMerge_Organization.sql"
, "db\procs\stage.spMerge_Provider.sql"
, "db\procs\stage.spMerge_Patient.sql"
, "db\procs\stage.spMerge_Encounter.sql"
, "db\procs\stage.spMerge_Condition.sql"
, "db\procs\stage.spMerge_Medication.sql"
, "db\procs\stage.spMerge_Procedure.sql"
, "db\procs\stage.spMerge_Claim.sql"
, "db\procs\stage.spMerge_ClaimLine.sql"
, "db\procs\stage.spLoad_All.sql"
, "db\views\api.vwLocation.sql"
, "db\views\api.vwCode.sql"
, "db\views\api.vwUsState.sql"
, "db\views\api.vwPayer.sql"
, "db\views\api.vwOrganization.sql"
, "db\views\api.vwProvider.sql"
, "db\views\api.vwPatient.sql"
, "db\views\api.vwEncounter.sql"
, "db\views\api.vwCondition.sql"
, "db\views\api.vwMedication.sql"
, "db\views\api.vwProcedure.sql"
, "db\views\api.vwClaim.sql"
, "db\views\api.vwClaimLine.sql"
, "db\security\role_Developer.sql"
, "db\security\role_Clinician.sql"
, "db\security\role_Loader.sql"
, "db\security\role_Extractor.sql"
, "db\security\login_Loader.sql"
, "db\security\login_Extractor.sql"
, "db\security\login_Developer.sql"
, "db\security\login_Clinician.sql"
, "db\cdc\cdc.EnableDatabase.sql"
, "db\cdc\cdc.ref_Location.sql"
, "db\cdc\cdc.ref_Code.sql"
, "db\cdc\cdc.ref_Payer.sql"
, "db\cdc\cdc.ref_Organization.sql"
, "db\cdc\cdc.ref_Provider.sql"
, "db\cdc\cdc.clinical_Patient.sql"
, "db\cdc\cdc.clinical_Encounter.sql"
, "db\cdc\cdc.clinical_Condition.sql"
, "db\cdc\cdc.clinical_Medication.sql"
, "db\cdc\cdc.clinical_Procedure.sql"
, "db\cdc\cdc.clinical_Claim.sql"
, "db\cdc\cdc.clinical_ClaimLine.sql"
, "db\cdc\cdc.Jobs.sql"
, "db\procs\stage.spSimulate_Changes.sql"
, "db\tables\etl.CdcWatermark.sql"
)

foreach ($File in $Files) {
  Write-Host "deploying $File"
  sqlcmd -S $Server -E -C -b -I -d $Database -i (Join-Path $Root $File)
  if ($LASTEXITCODE -ne 0) { throw "failed: $File" }
}

Write-Host "deploy done" -ForegroundColor Green