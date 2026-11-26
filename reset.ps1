# full clean reset and fresh run: stops Airflow, rebuilds SQL Server (DB, CDC, watermark),
# wipes Databricks, starts everything again (start.ps1) and triggers the DAG once.
[string]$Root = $PSScriptRoot
[string]$Compose = Join-Path $Root "airflow\docker-compose.yml"

& (Join-Path $Root "stop.ps1")
& (Join-Path $Root "tools\deploy_db.ps1") -Reset
& (Join-Path $Root "tools\reset_databricks.ps1")
& (Join-Path $Root "start.ps1") -NoBrowser

docker compose -f $Compose exec -T airflow airflow dags unpause synthea_health_pipeline
docker compose -f $Compose exec -T airflow airflow dags trigger synthea_health_pipeline
if ($LASTEXITCODE -ne 0) { throw "could not trigger the DAG" }

Write-Host "reset done, DAG triggered" -ForegroundColor Green
Start-Process "http://localhost:8081/dags/synthea_health_pipeline"