# Airflow + Java (Synthea) + ODBC Driver 18 (SQL Server). Pipeline scripts get their own venv
# (/opt/pipeline) so their packages never clash with Airflow's.
FROM apache/airflow:3.0.2-python3.12

USER root
# man1 folder: openjdk install fails on slim images without it
RUN mkdir -p /usr/share/man/man1 \
 && apt-get update \
 && apt-get install -y --no-install-recommends curl gnupg openjdk-17-jre-headless \
 && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg \
 && curl -fsSL https://packages.microsoft.com/config/debian/12/prod.list -o /etc/apt/sources.list.d/mssql-release.list \
 && apt-get update \
 && ACCEPT_EULA=Y apt-get install -y --no-install-recommends msodbcsql18 unixodbc \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt /opt/pipeline-requirements.txt
RUN python -m venv /opt/pipeline \
 && /opt/pipeline/bin/pip install --no-cache-dir -r /opt/pipeline-requirements.txt

USER airflow