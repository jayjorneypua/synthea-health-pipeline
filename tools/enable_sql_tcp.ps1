# one-time machine setup (run as admin): enables TCP/IP on the default SQL Server instance, port 1433,
# so Docker containers (Airflow) can reach it at host.docker.internal,1433. Restarts SQL Server and Agent.
[string]$InstanceId = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL').MSSQLSERVER
[string]$Tcp = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\$InstanceId\MSSQLServer\SuperSocketNetLib\Tcp"

Set-ItemProperty -Path $Tcp -Name Enabled -Value 1
Set-ItemProperty -Path "$Tcp\IPAll" -Name TcpPort -Value "1433"
Set-ItemProperty -Path "$Tcp\IPAll" -Name TcpDynamicPorts -Value ""

# -Force also stops SQL Server Agent (it depends on SQL Server), so start it again after
Restart-Service MSSQLSERVER -Force
Start-Service SQLSERVERAGENT
Write-Host "TCP enabled on 1433 ($InstanceId)" -ForegroundColor Green