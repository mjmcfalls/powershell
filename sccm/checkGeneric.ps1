[CmdletBinding(
    SupportsShouldProcess = $True
)]
Param(
    [string]$File = "\\server\share\with\computers.csv"
    # [string]$PSPath,
    # [string]$log = "\\mh\ss\slop\tecmmx\test.log"
)

$Path = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
# $results = New-Object System.Collections.Generic.List[System.Object]
$csv = Import-Csv -Path $File

$type = 'REG_SZ'

$props = @{
    DefaultUserName   = '';
    DefaultPassword   = '';
    ForceAutoLogon    = '1';
    AutoAdminLogon    = '1';
    DefaultDomainName = 'MSJ';
}

$pc = $env:COMPUTERNAME

foreach ($row in $csv) {
    if ($row.workstation){
    if (($row.workstation).ToUpper().trim() -eq $pc.ToUpper().trim()) {
        Write-Host "Found $($Pc)"
        Foreach ($key in $props.keys) {
            if ($key -eq "DefaultUserName") {
                Write-Host "$($key):$($row.username)"
                # $psobj.DefaultUserName = $row.username 
                # Write-host "\\$($row.workstation) cmd / `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($row.username)`""
                invoke-expression "cmd /c `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($row.username)`""
            }
            if ($key -eq "DefaultPassword") { 
                Write-Host "$($key):$($row.password)"
                # $psobj.DefaultPassword = $row.password
                # Write-Host "\\$($row.workstation) cmd /c `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($row.password)`""
                invoke-expression "cmd /c `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($row.password)`" "
            }

            if ($key -eq "ForceAutoLogon") { 
                Write-Host "$($key):$($props[$key])"
                # $psobj.ForceAutoLogon = $props[$key]
                # Write-Host "\\$($row.workstation) cmd /c `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($props[$key])`""
                invoke-expression "cmd /c `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($props[$key])`""
            }

            if ($key -eq "AutoAdminLogon") { 
                Write-Host "$($key):$($props[$key])"
                # $psobj.AutoAdminLogon = $props[$key]
                # Write-Host "\\$($row.workstation) `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($props[$key])`""
                invoke-expression "cmd /c `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($props[$key])`""
            }

            if ($key -eq "DefaultDomainName") { 
                Write-Host "$($key):$($props[$key])"
                # $psobj.DefaultDomainName = $props[$key]
                # Write-Host "\\$($row.workstation) cmd /c `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($props[$key])`""
                invoke-expression "cmd /c `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($props[$key])`""
            }
            # start-sleep -Milliseconds 500
        }
        # Unlock-ADAccount -Identity ($row.username)
        invoke-expression "shutdown /r /f /t 5"

    }
}
}