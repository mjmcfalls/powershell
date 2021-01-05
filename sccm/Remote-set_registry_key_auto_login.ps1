[CmdletBinding(
    SupportsShouldProcess = $True
)]
Param(
    [string]$File = "\\folder\share\with\Utarget.csv",
    [string]$PSPath,
    [string]$log = "\\server\share\logs\test.log"
)

$Path = 'HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
$results = New-Object System.Collections.Generic.List[System.Object]
$csv = Import-Csv -Path $File

$type = 'REG_SZ'

$props = @{
    DefaultUserName   = '';
    DefaultPassword   = '';
    ForceAutoLogon    = '1';
    AutoAdminLogon    = '1';
    DefaultDomainName = 'MSJ';
}

foreach ($row in $csv) {
    if ($row.workstation) {
        $psobj = [PSCustomObject]@{
            DefaultUserName   = ''
            DefaultPassword   = ''
            ForceAutoLogon    = ''
            AutoAdminLogon    = ''
            DefaultDomainName = ''
            Updated           = ''
            Hostname          = ''
            Location          = ''
            Usage             = ''
        }

        $psobj.hostname = $row.workstation
        $psobj.Location = $row.Location
        $psobj.Usage = $row.Usage
        $psobj.DefaultUserName = $row.username 
        $psobj.DefaultPassword = $row.password

        if (Test-Connection -Quiet -Computer $row.workstation -Count 1) {

            # $psobj.hostname = $row.workstation
            # $psobj.Location = $row.Location
            # $psobj.Usage = $row.Usage

            # $pinfo = New-Object System.Diagnostics.ProcessStartInfo
            # $pinfo.FileName = "$($PSPath)"
            # $pinfo.RedirectStandardError = $true
            # $pinfo.RedirectStandardOutput = $true
            # $pinfo.UseShellExecute = $false
            # $pinfo.Arguments = "-nobanner \\$($row.workstation) cmd /c `"reg query `"$($Path)`" /v DefaultUserName`""

            # $p = New-Object System.Diagnostics.Process
            # $p.StartInfo = $pinfo
            # $p.Start() | Out-Null
            # $p.WaitForExit()
            # $stdout = $p.StandardOutput.ReadToEnd()
            # $stderr = $p.StandardError.ReadToEnd()
            # Write-Host "******"
            # Write-Host "stdout: $stdout"
            # Write-Host "******"
            # Write-Host "stderr: $stderr"
            # Write-Host "******"
            # Write-Host "exit code: " + $p.ExitCode
  

            # If ($stdout.Contains($row.username)) {
            #     # Write-Host "stdout: $stdout"
            #     Write-Host "Usernames Match - $($row.username) - $($row.workstation)"

            #     Foreach ($key in $props.keys) {
            #         if ($key -eq "DefaultUserName") {
            #             # Write-Host "$($key):$($row.username)"
            #             $psobj.DefaultUserName = $row.username
            #             # start-process -Filepath "$($PSPath)" -argumentlist "\\$($row.workstation) reg add `"$path`" /f /v $($key) /t $type /d $($row.username)"
            #         }
            #         if ($key -eq "DefaultPassword") { 
            #             # Write-Host "$($key):$($row.password)"
            #             $psobj.DefaultPassword = $row.password
            #             # start-process -Filepath "$($PSPath)" -argumentlist "\\$($row.workstation) reg add `"$path`" /f /v $($key) /t $type /d $($row.password)"
            #         }

            #         if ($key -eq "ForceAutoLogon") { 
            #             # Write-Host "$($key):$($props[$key])"
            #             $psobj.ForceAutoLogon = $props[$key]
            #             # start-process -Filepath "$($PSPath)" -argumentlist "\\$($row.workstation) reg add `"$path`" /f /v $($key) /t $type /d $($props[$key])"
            #         }

            #         if ($key -eq "AutoAdminLogon") { 
            #             # Write-Host "$($key):$($props[$key])"
            #             $psobj.AutoAdminLogon = $props[$key]
            #             # start-process -Filepath "$($PSPath)" -argumentlist "\\$computer reg add `"$path`" /f /v $($key) /t $type /d $($props[$key])"
            #         }

            #         if ($key -eq "DefaultDomainName") { 
            #             # Write-Host "$($key):$($props[$key])"
            #             $psobj.DefaultDomainName = $props[$key]
            #             # start-process -Filepath "$($PSPath)" -argumentlist "\\$($row.workstation) reg add `"$path`" /f /v $($key) /t $type /d $($props[$key])"
            #         }
            #     }
            #     $psobj.Updated = 0
            # }
            # else { 
                Try {
                    Write-Host "Usernames Do Not Match - $($row.username) - $($row.workstation)"
                    Foreach ($key in $props.keys) {
                        if ($key -eq "DefaultUserName") {
                            # Write-Host "$($key):$($row.username)"
                            $psobj.DefaultUserName = $row.username 
                            # Write-host "\\$($row.workstation) cmd / `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($row.username)`""
                            start-process -Filepath "$($PSPath)" -argumentlist "\\$($row.workstation) cmd /c `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($row.username)`""
                        }
                        if ($key -eq "DefaultPassword") { 
                            # Write-Host "$($key):$($row.password)"
                            $psobj.DefaultPassword = $row.password
                            Write-Host "\\$($row.workstation) cmd /c `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($row.password)`""
                            start-process -Filepath "$($PSPath)" -argumentlist "\\$($row.workstation) cmd /c `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($row.password)`""
                        }

                        if ($key -eq "ForceAutoLogon") { 
                            # Write-Host "$($key):$($props[$key])"
                            $psobj.ForceAutoLogon = $props[$key]
                            # Write-Host "\\$($row.workstation) cmd /c `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($props[$key])`""
                            start-process -Filepath "$($PSPath)" -argumentlist "\\$($row.workstation) cmd /c `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($props[$key])`""
                        }

                        if ($key -eq "AutoAdminLogon") { 
                            # Write-Host "$($key):$($props[$key])"
                            $psobj.AutoAdminLogon = $props[$key]
                            # Write-Host "\\$($row.workstation) `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($props[$key])`""
                            start-process -Filepath "$($PSPath)" -argumentlist "\\$computer cmd /c `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($props[$key])`""
                        }

                        if ($key -eq "DefaultDomainName") { 
                            # Write-Host "$($key):$($props[$key])"
                            $psobj.DefaultDomainName = $props[$key]
                            # Write-Host "\\$($row.workstation) cmd /c `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($props[$key])`""
                            start-process -Filepath "$($PSPath)" -argumentlist "\\$($row.workstation) cmd /c `"reg add `"$path`" /f /v `"$($key)`" /t `"$type`" /d $($props[$key])`""
                        }
                        # start-sleep -Milliseconds 500
                    }
                    # Unlock-ADAccount -Identity ($row.username)
                    start-process -Filepath "$($PSPath)" -argumentlist "\\$($row.workstation) shutdown /r /f"
                    # $status = $True
                    $psobj.Updated = 1
                }
                Catch {
                    $psobj.Updated = 2
                    # $status = $False
                }

                If ($psobj.Updated) {
                    # Start-sleep 
                    # Write-Host "Set ADuser Description: Generic User for: $($row.workstation)"
                    # Set-ADUser -Identity ($row.username) -Description "Generic User for: $($row.workstation)"
                }
            }
            else{ 
                $psobj.Updated = 0
            }
            $results.Add($psobj)

        }
    }
#     else {
#     }
# # }

$results
