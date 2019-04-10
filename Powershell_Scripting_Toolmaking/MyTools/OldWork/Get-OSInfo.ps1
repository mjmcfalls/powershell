[CmdletBinding()]
    param(
        [string[]]$ComputerName
    )

Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName |
    Select-Object Version,ServicePackMajorVersion,BuildNumber,OSArchitecture

