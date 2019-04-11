[Cmdletbinding()]
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
