Test-NetConnection precwap021 -Port 8081

Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*8081*"}

netstat -ano | findstr :8081