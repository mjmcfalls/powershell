[CmdletBinding(
    SupportsShouldProcess = $True
)]
param(
    # generictype should be either "user" or "trackingboard" to match users or tracking boards
    [String]$genericType,
    [string]$Restart,
    [String]$csv = "\\server\share\users_list.csv",
    [string]$pwd,
    [string]$app,
    [string]$facility,
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
    site3  = @{user = "site3gu[^t]"; trackingboard = "site3gut"; pacs = "site3pacs" };
    site4 = @{user = "site4gu[^t]"; trackingboard = "site4gut"; pacs = "site4pacs" };
    site5 = @{user = "site5gu[^t]"; trackingboard = "site5ut"; pacs = "site5pacs" };
    site6 = @{user = "site6gu[^t]"; trackingboard = "site6gut"; pacs = "site6pacs" };
    site7 = @{user = "site7gu[^t]"; trackingboard = "site7gut"; pacs = "site7pacs" };
    site8 = @{user = "site8gu[^t]"; trackingboard = "site8gut"; pacs = "site8pacs" };
    site9 = @{user = "site9gu[^t]"; trackingboard = "site9gut"; pacs = "site9pacs" };
    site10 = @{user = "site10gu[^t]"; trackingboard = "site10gut"; pacs = "site10pacs" };
    site11 = @{user = "site11gu[^t]"; trackingboard = "site11gut"; pacs = "site11pacs" };
}

$taskLookup = @{
    firstnet    = @{File = 'autoLaunchApp.ps1'; description = "Auto Launch Firstnet on a tracking board"; name = "Firstnet - Autolaunch"; execute = "C:\Windows\System32\wscript.exe"; command = "c:\admin\quietLaunchTask.vbs `"c:\Admin\autoLaunchApp.ps1 -app firstnet`"" }
    surginet    = @{File = 'autoLaunchApp.ps1'; description = "Auto Launch Surginet on a tracking board"; name = "Surginet - Autolaunch"; execute = "C:\Windows\System32\wscript.exe"; command = "c:\admin\quietLaunchTask.vbs `"c:\Admin\autoLaunchApp.ps1 -app surginet`"" }
    spm         = @{File = 'autoLaunchApp.ps1'; description = "Auto-launch SPM Needs List"; name = "SPM Needs List - Autolaunch"; execute = "C:\Windows\System32\wscript.exe"; command = "c:\admin\quietLaunchTask.vbs `"c:\Admin\autoLaunchApp.ps1 -app spm`"" }
    edcensusold = @{File = 'autoLaunchApp.ps1'; description = "(2020-03-30 This is here for the removal tool and should not be deployed to prod."; name = "Realtime Census - Autolaunch"; execute = "C:\Windows\System32\wscript.exe"; command = "c:\admin\quietLaunchTask.vbs `"c:\Admin\autoLaunchApp.ps1 -app http`"" }
    edcensus    = @{File = 'autoLaunchApp.ps1'; description = "Auto-launch Realtime Census"; name = "Realtime Census - Autolaunch"; execute = "C:\Windows\System32\wscript.exe"; command = "c:\admin\quietLaunchTask.vbs `"c:\Admin\autoLaunchApp.ps1 -app http -uri `'TARGETURI`'`"" }
    getile      = @{File = 'autoLaunchApp.ps1'; description = "Auto-launch Tile"; name = "GE Tile - Autolaunch"; execute = "C:\Windows\System32\wscript.exe"; command = "c:\admin\quietLaunchTask.vbs `"c:\Admin\autoLaunchApp.ps1 -app http -uri `'TARGETURI`'`"" }
    perahealth  = @{File = 'autoLaunchApp.ps1'; description = "Auto-launch Health"; name = "Health - Autolaunch"; execute = "C:\Windows\System32\wscript.exe"; command = "c:\admin\quietLaunchTask.vbs `"c:\Admin\autoLaunchApp.ps1 -app http -uri `'TARGETURI`'`"" }
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

Add-Type @"
		using System;
		using System.Collections.Generic;
		using System.Text;
		using System.Runtime.InteropServices;

		namespace ComputerSystem
		{
		    public class LSAutil
		    {
		        [StructLayout(LayoutKind.Sequential)]
		        private struct LSA_UNICODE_STRING
		        {
		            public UInt16 Length;
		            public UInt16 MaximumLength;
		            public IntPtr Buffer;
		        }

		        [StructLayout(LayoutKind.Sequential)]
		        private struct LSA_OBJECT_ATTRIBUTES
		        {
		            public int Length;
		            public IntPtr RootDirectory;
		            public LSA_UNICODE_STRING ObjectName;
		            public uint Attributes;
		            public IntPtr SecurityDescriptor;
		            public IntPtr SecurityQualityOfService;
		        }

		        private enum LSA_AccessPolicy : long
		        {
		            POLICY_VIEW_LOCAL_INFORMATION = 0x00000001L,
		            POLICY_VIEW_AUDIT_INFORMATION = 0x00000002L,
		            POLICY_GET_PRIVATE_INFORMATION = 0x00000004L,
		            POLICY_TRUST_ADMIN = 0x00000008L,
		            POLICY_CREATE_ACCOUNT = 0x00000010L,
		            POLICY_CREATE_SECRET = 0x00000020L,
		            POLICY_CREATE_PRIVILEGE = 0x00000040L,
		            POLICY_SET_DEFAULT_QUOTA_LIMITS = 0x00000080L,
		            POLICY_SET_AUDIT_REQUIREMENTS = 0x00000100L,
		            POLICY_AUDIT_LOG_ADMIN = 0x00000200L,
		            POLICY_SERVER_ADMIN = 0x00000400L,
		            POLICY_LOOKUP_NAMES = 0x00000800L,
		            POLICY_NOTIFICATION = 0x00001000L
		        }

		        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
		        private static extern uint LsaRetrievePrivateData(
		                    IntPtr PolicyHandle,
		                    ref LSA_UNICODE_STRING KeyName,
		                    out IntPtr PrivateData
		        );

		        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
		        private static extern uint LsaStorePrivateData(
		                IntPtr policyHandle,
		                ref LSA_UNICODE_STRING KeyName,
		                ref LSA_UNICODE_STRING PrivateData
		        );

		        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
		        private static extern uint LsaOpenPolicy(
		            ref LSA_UNICODE_STRING SystemName,
		            ref LSA_OBJECT_ATTRIBUTES ObjectAttributes,
		            uint DesiredAccess,
		            out IntPtr PolicyHandle
		        );

		        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
		        private static extern uint LsaNtStatusToWinError(
		            uint status
		        );

		        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
		        private static extern uint LsaClose(
		            IntPtr policyHandle
		        );

		        [DllImport("advapi32.dll", SetLastError = true, PreserveSig = true)]
		        private static extern uint LsaFreeMemory(
		            IntPtr buffer
		        );

		        private LSA_OBJECT_ATTRIBUTES objectAttributes;
		        private LSA_UNICODE_STRING localsystem;
		        private LSA_UNICODE_STRING secretName;

		        public LSAutil(string key)
		        {
		            if (key.Length == 0)
		            {
		                throw new Exception("Key length zero");
		            }

		            objectAttributes = new LSA_OBJECT_ATTRIBUTES();
		            objectAttributes.Length = 0;
		            objectAttributes.RootDirectory = IntPtr.Zero;
		            objectAttributes.Attributes = 0;
		            objectAttributes.SecurityDescriptor = IntPtr.Zero;
		            objectAttributes.SecurityQualityOfService = IntPtr.Zero;

		            localsystem = new LSA_UNICODE_STRING();
		            localsystem.Buffer = IntPtr.Zero;
		            localsystem.Length = 0;
		            localsystem.MaximumLength = 0;

		            secretName = new LSA_UNICODE_STRING();
		            secretName.Buffer = Marshal.StringToHGlobalUni(key);
		            secretName.Length = (UInt16)(key.Length * UnicodeEncoding.CharSize);
		            secretName.MaximumLength = (UInt16)((key.Length + 1) * UnicodeEncoding.CharSize);
		        }

		        private IntPtr GetLsaPolicy(LSA_AccessPolicy access)
		        {
		            IntPtr LsaPolicyHandle;

		            uint ntsResult = LsaOpenPolicy(ref this.localsystem, ref this.objectAttributes, (uint)access, out LsaPolicyHandle);

		            uint winErrorCode = LsaNtStatusToWinError(ntsResult);
		            if (winErrorCode != 0)
		            {
		                throw new Exception("LsaOpenPolicy failed: " + winErrorCode);
		            }

		            return LsaPolicyHandle;
		        }

		        private static void ReleaseLsaPolicy(IntPtr LsaPolicyHandle)
		        {
		            uint ntsResult = LsaClose(LsaPolicyHandle);
		            uint winErrorCode = LsaNtStatusToWinError(ntsResult);
		            if (winErrorCode != 0)
		            {
		                throw new Exception("LsaClose failed: " + winErrorCode);
		            }
		        }

		        public void SetSecret(string value)
		        {
		            LSA_UNICODE_STRING lusSecretData = new LSA_UNICODE_STRING();

		            if (value.Length > 0)
		            {
		                //Create data and key
		                lusSecretData.Buffer = Marshal.StringToHGlobalUni(value);
		                lusSecretData.Length = (UInt16)(value.Length * UnicodeEncoding.CharSize);
		                lusSecretData.MaximumLength = (UInt16)((value.Length + 1) * UnicodeEncoding.CharSize);
		            }
		            else
		            {
		                //Delete data and key
		                lusSecretData.Buffer = IntPtr.Zero;
		                lusSecretData.Length = 0;
		                lusSecretData.MaximumLength = 0;
		            }

		            IntPtr LsaPolicyHandle = GetLsaPolicy(LSA_AccessPolicy.POLICY_CREATE_SECRET);
		            uint result = LsaStorePrivateData(LsaPolicyHandle, ref secretName, ref lusSecretData);
		            ReleaseLsaPolicy(LsaPolicyHandle);

		            uint winErrorCode = LsaNtStatusToWinError(result);
		            if (winErrorCode != 0)
		            {
		                throw new Exception("StorePrivateData failed: " + winErrorCode);
		            }
		        }
		    }
		}
"@
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

Function Invoke-PrecacheProfile {
    Param(
        [string]$pass,
        [string]$user
    )
    $spwd = ConvertTo-SecureString $pass -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential $user, $spwd
    Write-Log -Level "INFO" -Message "Running C:\windows\System32\ipconfig.exe /registerdns" -logfile $LogFile
    Start-Process -LoadUserProfile C:\Windows\System32\ipconfig.exe /registerdns -Credential $cred | Out-Null
}

Function Set-RegistryKey {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    Param(  
        [String]$Path,
        [String]$Name,
        [String]$Value,
        [String]$LogFile
    )
    Set-ItemProperty -Path $Path -Name $Name -Value $Value
}

Function New-RegistryKey {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    Param(  
        [String]$Path,
        [String]$Name,
        [String]$LogFile
    )
    $results = New-Item -Path $Path -Name $Name -Force
}

Function Set-AutoLogon {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    Param(
        [String]$DefaultUserName,
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

    foreach ($key in $targets.keys) {
        Write-Log -Level "INFO" -Message "Setting $($key)" -logfile $LogFile
        switch ($key) {
            "AutoAdminLogon" {
                Set-RegistryKey -Path $RegistryPath -Name $key -Value "1"
                break
            }
            "ForceAutoLogon" {
                Set-RegistryKey -Path $RegistryPath -Name $key -Value "1"
                break
            }
            "DefaultDomain" {
                Set-RegistryKey -Path $RegistryPath -Name $key -Value $DefaultDomain 
                break
            }
            "DefaultDomainName" {
                Set-RegistryKey -Path $RegistryPath -Name $key -Value $DefaultDomain 
                break
            }
            "DefaultUserName" {
                Set-RegistryKey -Path $RegistryPath -Name $key -Value $DefaultUserName
                break 
            }
            "DefaultPassword" {
                if ($pwd -ne "PESTERTEST") {
                    # Set-RegistryKey -Path $RegistryPath -Name $key -Value $pwd 
                    $r = Remove-ItemProperty -Path $RegistryPath -Name "DefaultPassword" -ErrorAction SilentlyContinue
                    Write-Log -Level "INFO" -Message "Configuring LSA Secret" -logfile $LogFile
                    $lsaUtil = New-Object ComputerSystem.LSAutil -ArgumentList "DefaultPassword"
                    Write-Log -Level "INFO" -Message "Setting LSA Secret" -logfile $LogFile
                    $lsaUtil.SetSecret($pwd)
                    break
                }
            }
            Default {
                # No match found
            }
        }
    }
}

Function Set-TrackingBoardApp {
    Param(
        [string]$username,
        [string]$app,
        [string]$src = "\\server\share\src",
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

    Write-Host "Attempting to set tracking board logic for $($app)`n"
    Write-Log -Level "INFO" -Message "Attempting to set tracking board logic for $($app)" -logfile $LogFile
    # Brute force removing any existing tasks
    foreach ($key in $taskLookup.keys) {
        Unregister-ScheduledTask -TaskName $taskLookup[$key].Name -Confirm:$false -ErrorAction SilentlyContinue
        if ($app -match $key) {
            Write-Host "Found Matching app - $($app)`n"
            Write-Log -Level "INFO" -Message "Found Matching app - $($app)" -logfile $LogFile
            $a = $key
        }
    }

    if ($a) {
        if ($taskLookup[$a]) {
            if ([System.Environment]::OSVersion.Version.Major -eq 10) {
                if (Test-Path -Path $dst) {
                    # Do nothing since path exists
                    # continue
                }
                else {
                    New-Item $dst -ItemType "directory" -Force | Out-Null
                }
    
                Write-Log -Level "INFO" -Message "Copying $($taskLookup[$a].File)" -logfile $LogFile
                Copy-Item (Join-Path -Path $src -ChildPath $taskLookup[$a].File) (Join-Path -Path $dst -ChildPath $taskLookup[$a].File) -Force

                Write-Log -Level "INFO" -Message "Copying $($sfile)" -logfile $LogFile
                Copy-Item (Join-Path -Path $src -ChildPath $sfile) (Join-Path -Path $dst -ChildPath $sfile) -Force

                if ($chromeExtensionUri) {
                    Write-Host "Setting Chrome extension - $($chromeExtensionUri)`n"
                    Write-Log -Level "INFO" -Message "Setting Chrome extension - $($ChromeExtensionUri)" -logfile $LogFile
                    New-RegistryKey -Path $ChromeRegPath -Name $ChromeExtensionId
                    Set-RegistryKey -Path "$($ChromeRegPath)\$($ChromeExtensionId)" -Name "$($ChromeRegName)" -Value "https://clients2.google.com/service/update2/crx"
                }

                if ($uri) {
                    Write-Host "Setting uri - $($uri)`n"
                    Write-Log -Level "INFO" -Message "Setting uri - $($uri)" -logfile $LogFile
                    $command = ($taskLookup[$a].command).Replace("TARGETURI", $uri)

                    $result = Set-SCTask -user "$($username.trim())" -name $taskLookup[$a].name -Description $taskLookup[$a].description -execute $taskLookup[$a].execute -command $command
                }
                else {
                    $result = Set-SCTask -user "$($username.trim())" -name $taskLookup[$a].name -Description $taskLookup[$a].description -execute $taskLookup[$a].execute -command $taskLookup[$a].command
                }
            }
            else {
                # Throw incompatiable version or build Win 7 logic.
                Write-Log -Level "ERROR" -Message "Incompatible version of Windows!" -logfile $LogFile
                $result = $false
            }
        }
        else {
            $result = $false
        }
    }
    else { 
        Write-Log -Level "ERROR" -Message "No Matching application found!!" -logfile $LogFile
        $result = $false 
    }
    Write-Host "Result: $($result)"
    $result
}

Function Set-RebootTask {
    Param(
        [int]$seconds = 60
    )
    # Remove reboot scheduled task
    $rebootresult = Unregister-ScheduledTask -TaskName "Tracking Board - Reboot" -Confirm:$false -ErrorAction SilentlyContinue
    # Set base datetime for random offset
    $baseDateTime = Get-Date -date "02-05-2020 05:00:00"
    # Generate Random time offset between -10 and 10
    $offset = get-random -minimum -10 -maximum 10
    # Generate start time
    $startTime = Get-Date -Date $baseDateTime.AddMinutes($offset) -Format "hh:mm tt"
    # Set reboot scheduled task
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -executionPolicy bypass -WindowStyle Hidden -command shutdown /r /t $($seconds)"
    $trigger = New-ScheduledTaskTrigger -Daily -At "$($startTime)"
    $prinicpal = New-ScheduledTaskPrincipal -UserID "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $results = Register-scheduledTask -action $action -Trigger $trigger -TaskName "Tracking Board - Reboot" -Description "Daily Tracking board reboot At 05:00" -Principal $prinicpal

    $results 
}

Function Test-Lockfile {
    Param(
        [string]$File
    )
    Test-Path $File
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

Function Set-SCTask {
    param(
        $name,
        $user,
        $description,
        $execute,
        $command
    )
  
    $repetitionInterval = "PT5M"
    $taskAction = New-ScheduledTaskAction -Execute $execute -Argument $command
    $trigger = New-ScheduledTaskTrigger -AtLogon -User $user
    $results = Register-ScheduledTask -Action $taskAction -Trigger $trigger -TaskName "$($name)" -Description "$($description)" -User $user
    $results.Triggers.Repetition.Interval = $repetitionInterval
    $results | Set-ScheduledTask | Out-Null

    $results

}

Function Find-GenericAccount {
    Param(
        [string]$acct,
        [string]$Computer,
        [string]$facility,
        [string]$app,
        [object]$csv,
        $lookup
    )

    $result = $null

    switch ($acct) {
        "user" {
            $items = ($csv | Where-Object { $_.hostname.ToLower() -eq $Computer.ToLower() -and $_.username.ToLower() -match $lookup.$facility.user })
            if ($items) {
                if ($items.length) {
                    $result = $items[0]
                }
                else {
                    $result = $items 
                }
            }
            else {
                $items = ($csv | Where-Object { $_.hostname.ToLower() -eq "" -and $_.username.ToLower() -match $lookup.$facility.user })  
                $result = $items[0]
            }
        }
        "pacs" {
            $items = ($csv | Where-Object { $_.hostname.ToLower() -eq $Computer.ToLower() -and $_.username.ToLower() -match $lookup.$facility.pacs })
            if ($items) {
                if ($items.length) {
                    $result = $items[0]
                }
                else {
                    $result = $items 
                }
            }
            else {
                $items = ($csv | Where-Object { $_.hostname.ToLower() -eq "" -and $_.username.ToLower() -match $lookup.$facility.pacs })  
                $result = $items[0]
            }
        }
        "trackingboard" {
            $items = ($csv | Where-Object { $_.app -match $app -and $_.username.ToLower() -match $lookup.$facility.trackingboard -and $_.hostname.ToLower() -eq $Computer.ToLower() })
            if ($items) {
                if ($items.length) {
                    $result = $items[0]
                }
                else {
                    $result = $items 
                }
            }
            else {
                $items = ($csv | Where-Object { $_.app -match "" -and $_.username.ToLower() -match $lookup.$facility.trackingboard -and $_.hostname.ToLower() -eq "" })  
                $result = $items[0]
            }
            break;
        }
        Default {
            # Do nothing
        }
    }
    $result
}

Function Start-UserConfig {
    param(
        [String]$genericType,
        [string]$Restart,
        [String]$csv,
        [string]$pwd,
        [string]$app,
        [string]$facility,
        [string]$logFile,
        [string]$configFile,
        [string]$firstRunUri,
        $lookup,
        $taskLookup
    )

    
    Write-Host "Starting UserConfig Function"
   
    Write-Log -Level "INFO" -Message "Searching generic accounts for $($env:computername)" -logfile $LogFile
    Write-Host "Searching generic accounts for $($env:computername)"

    $AutoLogonConfigFile = Import-Csv -Path $csv
    $genericUser = Find-GenericAccount -acct $genericType -Computer $env:computername -csv $AutoLogonConfigFile -facility $facility -app $app -lookup $lookup

    Write-Log -Level "INFO" -Message "genericUser - $($genericUser)" -logfile $LogFile

    if ($genericUser) {
        $userparams = @{ }
        Foreach ($prop in $genericUser.PsObject.Properties) {
            $userparams.Add($prop.Name, $prop.value)
        }
        Write-Host "Setting $($genericUser.username) on $($env:computername)"
        Set-AutoLogon -DefaultUserName $genericUser.username -pwd $pwd -logfile $LogFile
        if ($genericUser.app) {
            if ($genericUser.app -eq "getile") {
                # Write firstrun config file for ge tiles
                $firstrun = @{firstrun = $null }
                $config = @{ firstrun = $false; url = $firstRunUri }
                $firstrun.firstrun = $config
                $firstrun | ConvertTo-Json | Set-Content $configFile
            }
            
            Write-Host "Configuring trackingboard autolaunch - $($genericUser.app)"
            $r = Set-TrackingBoardApp @userparams -taskLookup $taskLookup -LogFile $LogFile

            if ($genericType -eq "trackingboard") {
                Write-Host "Configuring trackingboard daily reboot." 
                $rbsc = Set-RebootTask -seconds $seconds
            }
        }
        else {
            Write-Host "No trackingboard autolaunch to configure for $($genericUser.username)."
            Write-Log -Level "INFO" -Message "No trackingboard autolaunch to configure for $($genericUser.username)." -logfile $LogFile
        }
        # Update CSV with computer name
        $newcsv = ForEach ($row in $AutoLogonConfigFile) { 
            if ($row.username -eq $genericUser.username) { 
                $row.hostname = $env:computername 
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
}
Function Invoke-Main {
    param(
        [String]$genericType,
        [string]$Restart,
        [String]$csv,
        [string]$pwd,
        [string]$app,
        [string]$facility,
        [int]$minSeconds = 60,
        [int]$maxSeconds = 120,
        [int]$seconds = 60,
        [int]$loopstart,
        [int]$loopEnd,
        [string]$lockFile,
        [string]$logFile,
        [string]$configFile,
        [string]$firstRunUri,
        $lookup,
        $taskLookup
    )
    
    Write-Log -Level "INFO" -Message "Parameters -- genericType: $($genericType);  Restart: $($Restart), App: $($app), Facility $($facility), csv: $($csv), Computer: $($env:computername)" -logfile $LogFile
    Write-Host "Parameters -- genericType: $($genericType);  Restart: $($Restart), App: $($app), Facility $($facility), csv: $($csv), Computer: $($env:computername)"

    if ( $facility -eq "----") {
        Write-Host "No Facility Selected!!"
        Throw "NoFacilitySelected"
    }

    $results = "Successfully configured generic user account!"

    $mainparams = @{ }
    Foreach ($key in $PSBoundParameters.Keys) {
        $mainparams.Add($key, $PSBoundParameters.$key)
    }

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
            Start-UserConfig @mainparams
        }
    }
    else { 
        Write-Log -Level "INFO" -Message "Setting Lockfile - $($lockFile)" -logfile $LogFile
        Set-LockFile -File $lockFile
        Start-UserConfig @mainparams
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