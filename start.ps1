# starts everything the pipeline needs: env vars, SQL Server Agent (CDC capture), Docker, Airflow.
# run with F5 in VS Code or .\start.ps1. Airflow UI: http://localhost:8081
[string]$Root = $PSScriptRoot
[string]$Compose = Join-Path $Root "airflow\docker-compose.yml"

# 1. secrets: load from the user env into this session (VS Code may predate them)
foreach ($Name in @('SYNTHEA_LOADER_PWD', 'SYNTHEA_EXTRACTOR_PWD', 'SYNTHEA_DATABRICKS_TOKEN')) {
  [string]$Value = [Environment]::GetEnvironmentVariable($Name, 'User')
  if ([string]::IsNullOrEmpty($Value)) { throw "$Name is not set" }
  Set-Item "env:$Name" $Value
}

# 2. SQL Server Agent (needs admin to start, so it asks UAC only when it is stopped)
if ((Get-Service SQLSERVERAGENT).Status -ne 'Running') {
  Write-Host "starting SQL Server Agent (UAC prompt)..."
  Start-Process powershell -Verb RunAs -Wait -ArgumentList '-NoProfile', '-Command', 'Start-Service SQLSERVERAGENT'
}
if ((Get-Service SQLSERVERAGENT).Status -ne 'Running') { throw "SQL Server Agent is not running" }
Write-Host "SQL Server Agent running"

# 3. Docker Desktop
docker info *> $null
if ($LASTEXITCODE -ne 0) {
  Write-Host "starting Docker Desktop..."
  Start-Process "$env:ProgramFiles\Docker\Docker\Docker Desktop.exe"
  [int]$Waited = 0
  while ($Waited -lt 180) {
    Start-Sleep -Seconds 5
    $Waited = $Waited + 5
    docker info *> $null
    if ($LASTEXITCODE -eq 0) { break }
  }
  if ($LASTEXITCODE -ne 0) { throw "Docker did not start within 180s" }
}
Write-Host "Docker running"

# 4. Airflow
docker compose -f $Compose up -d
if ($LASTEXITCODE -ne 0) { throw "docker compose up failed" }

[bool]$Ready = $false
for ([int]$I = 0; $I -lt 36; $I++) {
  try {
    Invoke-WebRequest -Uri "http://localhost:8081" -UseBasicParsing -TimeoutSec 5 | Out-Null
    $Ready = $true
    break
  } catch {
    Start-Sleep -Seconds 5
  }
}
if ($Ready -eq $false) { throw "Airflow UI did not come up within 180s, check: docker compose -f airflow\docker-compose.yml logs" }

Write-Host "Airflow ready: http://localhost:8081" -ForegroundColor Green
Start-Process "http://localhost:8081"