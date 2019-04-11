[CmdletBinding()]
    param(
        [string[]]$ComputerName,
        [string]$DriveType=3,
        [int]$PercentFree=99
    )

Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=$($DriveType)" -Computername $ComputerName |
    Where-Object { $_.FreeSpace / $_.Size * 100 -lt $PercentFree }