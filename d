Get-NetFirewallRule | Where-Object {$_.DisplayName -like "*8081*"}

netstat -ano | findstr :8081