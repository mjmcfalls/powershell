# Powershell

My random powershell stuff.


### Remove Items older than 30 days
```powershell
Get-ChildItem $path | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item
```


#### Using Windows API to access long file names.
Prepend '\\?\UNC' to a UNC path; ex: 
```powershell
  Get-ChildItem -LiteralPath '\\?\UNC\Server\Share'
  ```
#### Test if Directory is empty
```powershell
((Get-ChildItem $Path -Force | Select-Object -First 1 | Measure-Object).Count -eq 0)
```
