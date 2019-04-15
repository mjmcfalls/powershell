# Powershell

My random powershell stuff.


### Remove Items older than 30 days
```powershell
Get-ChildItem $path | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(30) } | Remove-Item
```
