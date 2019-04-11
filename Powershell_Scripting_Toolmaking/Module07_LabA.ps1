Function Get-ServiceInfo {
    [CmdletBinding()]
    param(
    [string]$ComputerName
    )

    Process{
        $services = Get-WmiObject -Class Win32_Service -filter "state='Running'" -ComputerName $ComputerName

        Write-Host "Found $($services.count) on $($ComputerName)" #–Foreground Green
    
        $services | Sort -Property startname,name | Select-Object -Property startname,name,startmode,computername
    }
}
