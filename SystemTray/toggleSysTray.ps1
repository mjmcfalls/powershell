[CmdletBinding()]
param(
    $domain = "domain",
    [int]$seconds = 5,
    [int]$milliseconds = 150,
    [string]$adminuser = "domain\serviceAccount",
    [string]$keyFile = "\\server\share\Encrypted\key\SysTray.key",
    # [string]$passFile = "\\mh\ss\SLOP\tecmmx\Scripts\src\pass.txt",
    [string]$pwd = "AES-Encryptedkey",
    [string]$ProgressPreference = "SilentlyContinue",
    [string]$logfile = "c:\temp\toggleTray.err"
)


Function Get-RegkeyState {
    param(
        $sid
    )
    $state = Get-ItemProperty HKU:\$($sid)\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer -Name NoTrayItemsDisplay -ErrorAction SilentlyContinue
    $state.NoTrayItemsDisplay
}

Function Check-Device {

    $adapters = Get-netadapter

    Foreach ($adapter in $adapters) {
        # $adapter.InterfaceDescription
        if (($adapter.InterfaceDescription).toLower() -match "anyconnect") {
            if (($adapter.Status.toLower() -match "Up")) {
                # Write-host "Anyconnect - $($adapter.Name) - $($adapter.Status)"
                Write-Warning "This tool does not support devices on the VPN!"
                Write-Warning "The tool will exit in 30 seconds."
                Start-Sleep 30
                Throw "VPNConnected"
            }
        }
    }
}

function Restart-Explorer {
    Try {
        Start-Process -FilePath "explorer.exe" -WorkingDirectory "c:\Windows"
        C:\windows\explorer.exe
    }
    catch { 
        Write-Host "Cannot start Explorer.exe"
        Write-Host "$_"
    }
}

Function Stop-Explorer {
    taskkill /im explorer.exe /f | Out-Null
}

Function Toggle-SysTray {
    param(
        $sid
    )
    $psDrive = New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS
    $trayItemsDisplay = Get-ItemProperty HKU:\$($sid)\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer -Name NoTrayItemsDisplay -ErrorAction SilentlyContinue
    Write-Host "TrayItemsDisplay: $($trayItemsDisplay.NoTrayItemsDisplay)"

    if ($trayItemsDisplay) {
        switch ($trayItemsDisplay.NoTrayItemsDisplay) {
            0 {  
                taskkill /im explorer.exe /f | Out-Null
                Set-ItemProperty HKU:\$($sid)\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer -Name NoTrayItemsDisplay -Value 1
                Write-Host "Value is 0; setting to 1"
                Try {
                    Start-Process -FilePath "explorer.exe" -WorkingDirectory "c:\Windows"
                    # C:\windows\explorer.exe
                }
                catch { 
                    Write-Host "Cannot start Explorer.exe"
                    Write-Host "$_"
                }
            }
            1 { 
                taskkill /im explorer.exe /f | Out-Null
                Write-Host "Value is 1"
                Set-ItemProperty HKU:\$($sid)\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer -Name NoTrayItemsDisplay -Value 0
                Try {
                    Start-Process -FilePath "explorer.exe" -WorkingDirectory "c:\Windows"
                    # C:\windows\explorer.exe
                }
                catch { 
                    Write-Host "Cannot start Explorer.exe"
                    Write-Host "$_"
                }
            }
            Default {
                # Write-Host "Default statement"
                Write-Host "No matching registry value found - Current Value: $($trayItemsDisplay)"
                Break
            }
        }    
    }
    else {
        Write-Host "Registry key does not exist - HKU:\$($sid)\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer"
        $itemresults = New-Item -ItemType Directory -Path C:\Temp
        # Write-Host $itemresults
        Set-Content -Path $logfile -Value "RegistryKeyNotFound"

    }
    Remove-PSDrive -Name HKU
}

Check-Device

Clear-Host

$user = [System.Security.Principal.WindowsIdentity]::GetCurrent() 
$key = Get-Content $keyfile
$credential = New-Object -TypeName System.Management.Automation.PSCredential -argumentlist $adminuser, ($pwd | ConvertTo-SecureString -key $key)

$psDrive = New-PSDrive -PSProvider Registry -Name HKU -Root HKEY_USERS

do {
    $currstate = Get-RegkeyState -sid $user.User

    $selection = Read-Host "Toggle System Tray for $($user.Name): y/n"
    $selection = $selection.ToLower()
    
    if ($selection -eq "y") {
        Write-Host -NoNewLine "Working "
        
        # $results = Start-Jenkins -username $UserName -password $Password -computer $env:computername -sid "$($user.User)"
        $job = Start-Job -credential $credential -ScriptBlock ${Function:Toggle-SysTray} -argumentlist $user.user
        $returnstate = Get-RegkeyState -sid $user.User

        do {
            if (Test-Path -Path $logfile) {
                $content = Get-Content -Path $logfile
                if ($content -eq "RegistryKeyNotFound") {
                    Clear-Host
                    Write-Warning "The configuration of this device is not support by this tool!"
                    Write-Warning "The tool will close in 30 seconds"
                    Start-Sleep ($seconds * 6)
                    Throw "RegistryKeyNotFound"
                    # break
                }
            }
            Write-Host -NoNewline "."
            $returnstate = Get-RegkeyState -sid $user.User
            Start-Sleep -Milliseconds $milliseconds
        }
        while ($currstate -eq $returnstate)
        Write-Host -NoNewline "Done!"
        # Start-Process explorer.exe
        Start-Sleep -Milliseconds $milliseconds
        Clear-Host
    }
    elseif ($selection -eq "n") {
        break
    }
    else {
        Clear-Host
        Write-Host "$($selection) is invalid!"
    }
}
while ($selection -ne "n")

Remove-PSDrive -Name HKU
