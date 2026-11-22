# stops Airflow. -Purge also deletes the image, volumes (Airflow metadata/logs) and Docker build cache.
# SQL Server Agent keeps running on purpose: with SIMPLE recovery the log only truncates after CDC capture.
param([switch]$Purge)

[string]$Compose = Join-Path $PSScriptRoot "airflow\docker-compose.yml"

if ($Purge) {
  docker compose -f $Compose down --rmi all --volumes
  docker builder prune -f
  Write-Host "Airflow stopped and purged (next start rebuilds the image)" -ForegroundColor Yellow
} else {
  docker compose -f $Compose down
  Write-Host "Airflow stopped" -ForegroundColor Green
}