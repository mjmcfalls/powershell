[CmdletBinding(
    SupportsShouldProcess = $True
)]
param(
    [string]$user,
    [string]$computer,
    [string]$Restart = "yes",
    [String]$csv = "\\server\share\users.csv",
    [Switch]$offline,
    [int]$minSeconds = 60,
    [int]$maxSeconds = 120
)

$lockFile = "$($csv).lock"
$logFile = Join-Path -Path (Split-Path $csv) -ChildPath "logs\$($env:computername)_$(Get-Date -f yyyyMMddHHmm).log"
$configFile = "C:\admin\config.json"
$firstRunUri = "http://server.domain.tld/firstrun.html"

$lookup = @{
    site1 = @{user = "site1gu[^t]"; trackingboard = "site1gut"; pacs = "site1pacs" };
    site2 = @{user = "site2gu[^t]"; trackingboard = "site2gut"; pacs = "site2pacs" };
    site3  = @{user = "avlgu[^t]"; trackingboard = "site3gut"; pacs = "site3pacs" };
    site4 = @{user = "site4gu[^t]"; trackingboard = "site4gut"; pacs = "site4pacs" };
    site5 = @{user = "site5gu[^t]"; trackingboard = "site5gut"; pacs = "site5pacs" };
    site6 = @{user = "site6gu[^t]"; trackingboard = "hchhgut"; pacs = "site6pacs" };
    site7 = @{user = "site7gu[^t]"; trackingboard = "mhvagut"; pacs = "site7pacs" };
    site8 = @{user = "site8gu[^t]"; trackingboard = "mhmagut"; pacs = "site8pacs" };
    site9 = @{user = "site9gu[^t]"; trackingboard = "ncsagut"; pacs = "site9pacs" };
    site10 = @{user = "site10gu[^t]"; trackingboard = "ncdvgut"; pacs = "site10pacs" };
    site11 = @{user = "site11gu[^t]"; trackingboard = "trhbgut"; pacs = "site11pacs" };
}

$taskLookup = @{
    firstnet    = @{File = 'autoLaunchApp.ps1'; description = "Auto Launch Firstnet on a tracking board"; name = "Firstnet - Autolaunch"; execute = "C:\Windows\System32\wscript.exe"; command = "c:\admin\quietLaunchTask.vbs `"c:\Admin\autoLaunchApp.ps1 -app firstnet`"" }
    surginet    = @{File = 'autoLaunchApp.ps1'; description = "Auto Launch Surginet on a tracking board"; name = "Surginet - Autolaunch"; execute = "C:\Windows\System32\wscript.exe"; command = "c:\admin\quietLaunchTask.vbs `"c:\Admin\autoLaunchApp.ps1 -app surginet`"" }
    spm         = @{File = 'autoLaunchApp.ps1'; description = "Auto-launch Needs List"; name = "Needs List - Autolaunch"; execute = "C:\Windows\System32\wscript.exe"; command = "c:\admin\quietLaunchTask.vbs `"c:\Admin\autoLaunchApp.ps1 -app spm`"" }
    censusold = @{File = 'autoLaunchApp.ps1'; description = "(2020-03-30 This is here for the removal tool and should not be deployed to prod."; name = "Census - Autolaunch"; execute = "C:\Windows\System32\wscript.exe"; command = "c:\admin\quietLaunchTask.vbs `"c:\Admin\autoLaunchApp.ps1 -app http`"" }
    census    = @{File = 'autoLaunchApp.ps1'; description = "Auto-launch Realtime Census"; name = "Realtime Census - Autolaunch"; execute = "C:\Windows\System32\wscript.exe"; command = "c:\admin\quietLaunchTask.vbs `"c:\Admin\autoLaunchApp.ps1 -app http -uri `'TARGETURI`'`"" }
    tile      = @{File = 'autoLaunchApp.ps1'; description = "Auto-launch Tile"; name = "GE Tile - Autolaunch"; execute = "C:\Windows\System32\wscript.exe"; command = "c:\admin\quietLaunchTask.vbs `"c:\Admin\autoLaunchApp.ps1 -app http -uri `'TARGETURI`'`"" }
    health  = @{File = 'autoLaunchApp.ps1'; description = "Auto-launch Health"; name = "Health - Autolaunch"; execute = "C:\Windows\System32\wscript.exe"; command = "c:\admin\quietLaunchTask.vbs `"c:\Admin\autoLaunchApp.ps1 -app http -uri `'TARGETURI`'`"" }
}

$params = @{
    lockFile    = $lockFile;
    logFile     = $logFile;
    lookup      = $lookup;
    taskLookup  = $taskLookup;
    configFile  = $configFile;
    firstRunUri = $firstRunUri;
}

Foreach ($key in $PSBoundParameters.Keys) {
    $params.Add($key, $PSBoundParameters.$key)
}


Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
        [String]
        $Level = "INFO",
        [Parameter(Mandatory = $True)]
        [string]
        $Message,
        [Parameter(Mandatory = $False)]
        [string]
        $logfile
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    If ($logfile) {
        Add-Content $logfile -Value $Line
    }
    Else {
        Write-Output $Line
    }
}

Function Set-Lockfile {
    Param(
        [string]$File
    )
    $epoch = Get-Date -UFormat '%s'
    Set-Content -Path $File -Value "$($env:computername) - $($epoch)"
}
Function Clear-Lockfile {
    Param(
        [string]$File
    )
    Remove-Item -Path $File -Force
}

Function Test-Lockfile {
    Param(
        [string]$File
    )
    Test-Path $File
}

# Remove registry settings
Function Remove-RegistryKey {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    Param(  
        [String]$Path,
        [String]$Name,
        [String]$Value,
        [String]$LogFile
    )
    $results = Remove-ItemProperty -Path $Path -Name $Name #-Value $Value
    $results
}
Function Remove-AutoLogon {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    Param(
        # [String]$DefaultUserName,
        [String]$pwd,
        [String]$RegistryPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon",
        [String]$DefaultDomain = "msj.org",
        [String]$LogFile
        
    )
    # Set AdminAutoLogon
    $targets = @{
        AutoAdminLogon    = $null
        DefaultDomain     = $null
        DefaultDomainName = $null
        DefaultUserName   = $null
        DefaultPassword   = $null
        ForceAutoLogon    = $null

    }
    # $user = 
    foreach ($key in $targets.keys) {
        Write-Log -Level "INFO" -Message "Setting $($key)" -logfile $LogFile
        switch ($key) {
            "AutoAdminLogon" {
                Remove-RegistryKey -Path $RegistryPath -Name $key #-Value "1"
                break
            }
            "ForceAutoLogon" {
                Remove-RegistryKey -Path $RegistryPath -Name $key #-Value "1"
                break
            }
            "DefaultDomain" {
                # Remove-RegistryKey -Path $RegistryPath -Name $key -Value $DefaultDomain 
                break
            }
            "DefaultDomainName" {
                Remove-RegistryKey -Path $RegistryPath -Name $key #-Value $DefaultDomain 
                break
            }
            "DefaultUserName" {
                Remove-RegistryKey -Path $RegistryPath -Name $key #-Value $DefaultUserName
                break 
            }
            "DefaultPassword" {
                Remove-RegistryKey -Path $RegistryPath -Name $key #-Value $pwd 
                # $r = Remove-ItemProperty -Path $RegistryPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
                # Write-Log -Level "INFO" -Message "Configuring LSA Secret" -logfile $LogFile
                # $lsaUtil = New-Object ComputerSystem.LSAutil -ArgumentList "DefaultPassword"
                # Write-Log -Level "INFO" -Message "Setting LSA Secret" -logfile $LogFile
                # $lsaUtil.SetSecret($pwd)
                break
            }
            Default {
                # No match found
            }
        }
    }
}
# Remove LSA Secret

# Remove Autolaunch tasks
Function Remove-TrackingBoardApp {
    Param(
        [string]$username,
        [string]$app,
        [string]$dst = "c:\Admin",
        [string]$sfile = "quietLaunchTask.vbs",
        [string]$uri = $null,
        [string]$chromeExtensionUri = $null,
        [string]$chromeExtensionId = $null,
        [string]$chromeRegPath = $null,
        [string]$chromeRegName = $null,
        $taskLookup,
        $LogFile
    )
    # Brute force removing any existing tasks
    foreach ($key in $taskLookup.keys) {
        # $task = Get-ScheduledTask -TaskName $taskLookup[$key].Name -ErrorAction SilentlyContinue
        $results = Unregister-ScheduledTask -TaskName $taskLookup[$key].Name -Confirm:$false -ErrorAction SilentlyContinue
        if(Test-Path -Path (Join-Path -Path $dst -ChildPath $taskLookup[$key].File)){
            Remove-item (Join-Path -Path $dst -ChildPath $taskLookup[$key].File) -Force 
        }
        
    }
    
    if(Test-Path -Path (Join-Path -Path $dst -ChildPath $sfile)){
        Remove-item (Join-Path -Path $dst -ChildPath $sfile) -Force 
    }

    if ($chromeExtensionUri) {
        Write-Host "Removing Chrome extension - $($ChromeRegPath)\$($ChromeExtensionId)`n"
        Write-Log -Level "INFO" -Message "Removing Chrome extension - $($ChromeRegPath)\$($ChromeExtensionId)" -logfile $LogFile
        Remove-Item -Path "Microsoft.PowerShell.Core\Registry::$($ChromeRegPath)\$($ChromeExtensionId)" -Recurse #-Name "$($ChromeRegName)"
    }

    $results = 0
    $results
}


# Remove Reboot tasks
Function Remove-RebootTask {
    Param(
    )
    if (Get-ScheduledTask -Taskname "Tracking Board - Reboot") {
        $results = Unregister-ScheduledTask -TaskName "Tracking Board - Reboot"
    }
    else {
        $results = 1
    }
    $results 
}
# Remove host from data source

Function Find-GenericAccount {
    Param(
        [string]$Computer,
        [object]$csv
    )

    $items = ($csv | Where-Object { $_.hostname.ToLower() -eq $Computer.ToLower() })
      
    # Write-Host "Result: $($items)"
    $items
}

Function Remove-UserConfig {
    param(
        [string]$Restart,
        [String]$csv,
        [string]$logFile,
        [string]$configFile,
        [Switch]$offline,
        [string]$computer,
        $lookup,
        $taskLookup
    )

    # Write-Host "Starting Remove-UserConfig Function"
    Write-Host "Computer: $($computer); $($csv); switch: $($switch)"
    # Write-Log -Level "INFO" -Message "Searching generic accounts for $($computer)" -logfile $LogFile
    Write-Host "Searching generic accounts for $($computer)"
    $AutoLogonConfigFile = Import-Csv -Path $csv
    $genericUser = Find-GenericAccount -Computer $computer -csv $AutoLogonConfigFile

    Write-Log -Level "INFO" -Message "genericUser - $($genericUser)" -logfile $LogFile
    $results = $genericUser
    if ($genericUser) {
        $genericUser
        if ($offline) {
            # if ($PSCmdlet.ShouldProcess($name)){

            # }
            Write-host "Switch True"
            Write-Host "Offline removal"
            $results = "Offline removal"
            # Do nothing; hostname will be removed from csv later.
        }
        else {
            Write-Host "Switch false"
            $userparams = @{ }
            Foreach ($prop in $genericUser.PsObject.Properties) {
                $userparams.Add($prop.Name, $prop.value)
            }
            Write-Host "Removing $($genericUser.username) on $($env:computername)"
            # Remove-AutoLogon -logfile $LogFile
            if ($genericUser.app) {
                if ($genericUser.app -eq "getile") {
                    # Write firstrun config file for ge tiles
                    Remove-Item $configFile -Force
                }
                
                Write-Host "Configuring trackingboard autolaunch - $($genericUser.app)"
                $r = Remove-TrackingBoardApp @userparams -taskLookup $taskLookup -LogFile $LogFile
    
                if ($genericType -eq "trackingboard") {
                    Write-Host "Removing trackingboard daily reboot." 
                    $rbsc = Remove-RebootTask
                }
            }
            else {
                Write-Host "No trackingboard autolaunch to configure for $($genericUser.username)."
                Write-Log -Level "INFO" -Message "No trackingboard autolaunch to configure for $($genericUser.username)." -logfile $LogFile
            }
            $results = "switch true"
        }
  
        # # Update CSV with computer name
        $newcsv = ForEach ($row in $AutoLogonConfigFile) { 
            if ($row.hostname -eq $genericUser.hostname) { 
                $row.hostname = $null
            } 
            $row
        }
        # Write out CSV
        Write-Log -Level "INFO" -Message "Exporting CSV with new changes." -logfile $LogFile
        $newcsv | Export-Csv -Path $csv -NoTypeInformation 
    }
    else {
        Write-Log -Level "INFO" -Message "No Generic user account available!" -logfile $LogFile
        
        $results = "No Generic user account available!"
    }
    $results
}

Function Invoke-Main {
    param(
        [string]$Restart,
        [String]$csv,
        [int]$seconds = 60,
        [int]$loopstart,
        [int]$loopEnd,
        [string]$lockFile,
        [string]$logFile,
        [string]$configFile,
        [string]$firstRunUri,
        [Switch]$offline,
        $lookup,
        $taskLookup
    )
    
    Write-Log -Level "INFO" -Message "Parameters -- genericType: $($genericType);  Restart: $($Restart), App: $($app), Facility $($facility), csv: $($csv), Computer: $($env:computername)" -logfile $LogFile
    Write-Host "Parameters -- genericType: $($genericType);  Restart: $($Restart), App: $($app), Facility $($facility), csv: $($csv), Computer: $($env:computername)"

    $results = "Successfully configured generic user account!"

    $mainparams = @{ }
    Foreach ($key in $PSBoundParameters.Keys) {
        $mainparams.Add($key, $PSBoundParameters.$key)
    }
    $mainparams.Add("computer", $env:computername)

    if (Test-LockFile -File $lockFile) {    
        Write-Log -Level "INFO" -Message "Lockfile exists. Waiting . . ." -logfile $LogFile
        For ($i = $loopStart; $i -le $loopEnd; $i++) {
            if (Test-LockFile -File $lockFile) {
                Start-sleep -Seconds 1
            }
            else { 
                break
            }
        }

        if (Test-LockFile -File $lockFile) {
            $results = "Unable to clear lock in $($loopEnd) seconds" 
            Write-Log -Level "Warning" -Message "Unable to clear lock in $($loopEnd) seconds" -logfile $LogFile
            Throw "Unable to clear lock in $($loopEnd) seconds" 
        }
        else {
            Write-Log -Level "INFO" -Message "Setting Lockfile - $($lockFile)" -logfile $LogFile
            Set-LockFile -File $lockFile
            if ($switch) {

            }
            Remove-UserConfig @mainparams
        }
    }
    else { 
        Write-Log -Level "INFO" -Message "Setting Lockfile - $($lockFile)" -logfile $LogFile
        Set-LockFile -File $lockFile
        Remove-UserConfig @mainparams
    }

    Write-Log -Level "INFO" -Message "Clearing lock file." -logfile $LogFile
    Clear-LockFile -File $lockFile

    if ($Restart.ToLower() -eq "yes") {
        Write-Log -Level "INFO" -Message "Restarting $($env:computername)" -logfile $LogFile
        $seconds = get-random -minimum $minSeconds -maximum $maxSeconds
        Write-Host "Restarting in $($seconds) seconds."
        shutdown -r  -f -t $($seconds) 2> $null
    }
        
    $results
}

Invoke-Main @params