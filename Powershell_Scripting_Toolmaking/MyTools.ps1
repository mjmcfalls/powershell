function Invoke-OSShutdown{
    [CmdletBinding()]
    param(
    [int]$arg=0,
    [string[]]$Computername
    )

$validArgs = @(01,2,4.5,6,8,12)
if($validArgs.Contains($arg)){
    $results = Get-WmiObject -Class Win32_Operatingsystem -ComputerName $ComputerName |
        Invoke-WmiMethod -Name Win32Shutdown -Arg $arg
        if($results){
            Write-Host "Results: $($results.ResultsValue)"
        } else {
            Write-Host "Processed Successfully"
            }
    } else{
        Write-Host "Invalid Arg"
    }

}

function Get-DiskInfo{
    [CmdletBinding()]
    param(
        [string[]]$ComputerName,
        [string]$DriveType=3,
        [int]$PercentFree=99
    )

Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType=$($DriveType)" -Computername $ComputerName |
    Where-Object { $_.FreeSpace / $_.Size * 100 -lt $PercentFree }
}

function Get-OSInfo{
    [CmdletBinding()]
    param(
        [string[]]$ComputerName
    )

Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ComputerName |
    Select-Object Version,ServicePackMajorVersion,BuildNumber,OSArchitecture

}