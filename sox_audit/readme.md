### soxs audit notes

General requested fields and powershell mappings, along with timings of different comamnds.  These commands were run across the VPN, hence the large processing times; on a better connection, the time differences weren't significant.


This was originially running under Jenkins.


| Sox requested fields   | Powershell property                                                                      |
|--------------------------|------------------------------------------------------------------------------------------|
| username                 | SamAccountName                                                                           |
| Display Name             | DisplayName                                                                              |
| Company                  | Company                                                                                  |
| Department               | Department                                                                               |
| Acct_Created             | Created                                                                                  |
| Acct_disabled            | Enabled                                                                                  |
| Last_Logon_date          | LastLogonDate                                                                            |
| Acct_Password_Expiration | PasswordExpired                                                                          |
| Acct_Password_Last_set   | PasswordLastSet                                                                          |
| Employee_Type            | ?? (We don't set an attribute in AD for this; might be able to split it out from Title?) |
| UAC_Code                 | No idea what this is                                                                     |
| Title                    | Title                                                                                    |
| AD_Updated               | Modified                                                                                 |
| EmployeeID               | EmployeeID                                                                               |
| First name               | GivenName                                                                                |
| Last Name                | Surname                                                                                  |


Powershell to pull AD Users and associated properties:
```
Get-AdUser -Filter * -Properties SamAccountName, DisplayName, GivenName, Surname, EmployeeID, Company, Department, Created, Enabled, LastLogonDate, PasswordExpired, PasswordLastSet, Title, Modified | Select-Object -Property SamAccountName, DisplayName, GivenName, Surname, EmployeeID, Company, Department, Created, Enabled, LastLogonDate, PasswordExpired, PasswordLastSet, Title, Modified | Export-CSV .\src_data\users.csv -NoTypeInformation
```
```
Days              : 0
Hours             : 0
Minutes           : 7
Seconds           : 44
Milliseconds      : 242
Ticks             : 4642423308
TotalDays         : 0.005373175125
TotalHours        : 0.128956203
TotalMinutes      : 7.73737218
TotalSeconds      : 464.2423308
TotalMilliseconds : 464242.3308
```

Alternative Powershell 
```
Get-ADObject -Filter {(ObjectClass -eq "user")} | Get-AdUser -Properties SamAccountName, DisplayName, GivenName, Surname, EmployeeID, Company, Department, Created, Enabled, LastLogonDate, PasswordExpired, PasswordLastSet, Title, Modified | Select-Object -Property SamAccountName, DisplayName, GivenName, Surname, EmployeeID, Company, Department, Created, Enabled, LastLogonDate, PasswordExpired, PasswordLastSet, Title, Modified | Export-CSV .\src_data\users.csv -NoTypeInformation
```
```
Days              : 0
Hours             : 0
Minutes           : 30
Seconds           : 30
Milliseconds      : 136
Ticks             : 18301366231
TotalDays         : 0.0211821368414352
TotalHours        : 0.508371284194444
TotalMinutes      : 30.5022770516667
TotalSeconds      : 1830.1366231
TotalMilliseconds : 1830136.6231
```