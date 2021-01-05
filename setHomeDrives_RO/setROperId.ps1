[CmdletBinding(
    SupportsShouldProcess = $True
)]
param(
    [string]$server = '\\server\userHomes',
    [string]$aclFolder = '\\server\shared\somelocation\acl_bk',
    [string]$exportedPathFile = "\\server\shared\somelocation\exportedUserPaths.txt",
    [string]$logPath = '\\server\shared\somelocation\ro_logs\'

)

$usersFolders = @("users", "users2", "users3")
$decimalPlace = 2
$params = @{}

Foreach ($key in $MyInvocation.MyCommand.Parameters.GetEnumerator()) {
    $k = $key.key
    $val = Get-Variable $k -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value 
    if ($val) {
        $params.Add($k, $val)
    } 
}

if (-Not (Test-Path $aclFolder)) {
    New-Item -Type Directory $aclFolder | Out-Null
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
Function Get-Folders {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    param(
        [string]$server,
        [string[]]$usersFolders
    )
    $userDict = @{}
    foreach ($folder in $usersFolders) {
        $folPath = Join-Path -Path $server -ChildPath $folder
        $items = (Get-ChildItem $folPath -Directory).FullName | Split-Path -Leaf
        $userDict.Add($folder, $items)
    }
    $userDict
}

Function Find-User {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    param(
        [string]$user,
        $userDict
    )
    $locations = [System.Collections.ArrayList]@()
    foreach ($enum in $userDict.GetEnumerator()) {
        if ($enum.value -contains $user) {
            [void]$locations.add($enum.key)
        }
    }
    $locations
}

Function Update-Acls {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    param(
        [string]$user,
        [string]$server,
        [string]$aclFolder,
        [string]$logFile
    )
    $saveLocation = "$($aclFolder)\acl_bk_$($user)_$(Get-Date -f yyyyMMddHHmm)"

    Write-Log -Level "INFO" -Message "Saving ACLs to $($saveLocation)" -logfile $logFile
    $results = Invoke-Expression -Command:"icacls.exe $($server) /save $($saveLocation)" 

    Write-Log -Level "INFO" -Message "ACLs Change command: icacls.exe $($server) /grant:r $($user):`"(OI)(CI)(R)`"" -logfile $logFile
    $updateResults = Invoke-Expression -Command:"icacls.exe $($server) /grant:r $($user):`"(OI)(CI)(R)`""

    Write-Log -Level "INFO" -Message "Acl Change results $($updateResults)" -logfile $logFile
}

Function Start-RealTimeSearch {
    param(
        [string]$user,
        [string]$server,
        [string]$aclFolder,
        [string[]]$usersFolders,
        [string]$exportedPathFile
    )
    Write-Host "Searching $($server) for $($user)"
    $userDict = @{}
    $userDict = Get-Folders -Server $server -usersFolders $usersFolders

    $folders = Find-User -user $user -userDict $userDict
    foreach ($folder in $folders) {
        $targetFolder = Join-Path -Path (Join-Path -Path $server -ChildPath $Folder) -ChildPath $user
        Update-Acls -user $user -server $targetFolder -aclFolder $aclFolder
    }
}

Function Prompt-RealTimeSearch{
    Write-Host "Proceed with real-time search?  This will take time!"
    $choice = Read-Host -Prompt 'Y/N'
    $choice
}
Function Process-User {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    param(
        [string]$user,
        [string]$server,
        [string]$aclFolder,
        [string[]]$usersFolders,
        [string]$exportedPathFile,
        [string]$file,
        [string]$logPath
    )
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $params = @{}
    $logFile = Join-Path -Path $logPath -ChildPath "$($user)_$((Get-Date).toString("yyyyMMdd")).log"
    if(Test-Path $logFile){

    }
    else{
        New-Item -ItemType "file" -Path $logFile | Out-Null
    }

    Write-Log -Level "INFO" -Message "Processing $($user)" -logfile $logFile

    Foreach ($key in $PSBoundParameters.Keys) {
        $params.Add($key, $PSBoundParameters.$key)
    }
    $params.logFile = $logFile
    $params.user = $user

    if (Test-Path $exportedPathFile) {
        $paths = Get-Content $exportedPathFile | Select-String -Pattern "($user)$"
        if ($paths.length -eq 0){
            Write-Host "$($user) - Not Found."
            Write-Log -Level "INFO" -Message "$($user) - Not Found." -logfile $logFile
            # $choice = Prompt-RealTimeSearch
        }
        else{
            foreach ($path in $paths) {
                Write-Host "Updating-Acls on $($path)"
                Write-Log -Level "INFO" -Message "Updating-Acls on $($path)" -logfile $logFile
                Update-Acls -user $user -server $path -aclFolder $aclFolder -LogFile $LogFIle
            }
        }
    }
    else {
        Write-Host "Unable to open file cache."
        Write-Log -Level "INFO" -Message "Unable to open file cache." -logfile $logFile
        # $choice = Prompt-RealTimeSearch
    }
    # if($choice){
    #     if ($choice.ToLower() -eq "y") {
    #         # Real-time search
    #         # "Start real-time search"
    #         Start-RealTimeSearch @params
    #     }
    #     else {
    #         # "Exiting."
    #         # nothing to do here
    #     }
    # }
    $stopwatch.Stop()
    Write-Host "Read-only set in $([math]::Round($stopwatch.Elapsed.TotalSeconds,$decimalPlace)) seconds."
    Write-Log -Level "INFO" -Message "RO set in $([math]::Round($stopwatch.Elapsed.TotalSeconds,$decimalPlace)) seconds." -logfile $logFile
    
}

Function Check-Username{
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    param(
        [string]$user
    )
    $result = $null
    if ($user -like "*user*"){
        $result = $true
    }
    else{
        $result = $false
    }
    $result
}
Function Invoke-Main{
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    param(
        [string]$user,
        [string]$server,
        [string]$aclFolder,
        [string[]]$usersFolders,
        [string]$exportedPathFile,
        [string]$file,
        [string]$logPath
    )
    Clear-Host
    $exit = $false

    $mainLog = Join-Path -Path $logPath -ChildPath "main.log"
    if(Test-Path $mainLog){

    }
    else
    {
        New-Item -ItemType "file" -Path $mainLog | Out-Null
    }

    
    Do {
        $params = @{}
        Foreach ($key in $PSBoundParameters.Keys) {
            $params.Add($key, $PSBoundParameters.$key)
        }
        Write-Host "`nTo Exit - Leave both prompts blank (enter twice)`n"
        $sFile = Read-Host -Prompt 'Path to file (leave blank to skip)'
        if($sFile){

            if($sFile -match '"'){
                $sFile = $sFile.replace('"',"")
            }
 
            if(Test-Path -Path $sFile){
                # "Path is valid"
                $users = Get-Content $sFile
                foreach($u in $users){
                    Write-Host "`n"
 
                    if (Check-Username $u){
                        Write-Log -Level "INFO" -Message "$($u) - Cannot process name" -logfile $mainLog
                        Write-Host "$($u) - Cannot process name"
                    }
                    else{
                        $params.user = $u
                        Process-User @params
                    }
                }
            }
            else{
                Write-Host "Path is invalid - $($sFile)"
                Write-Log -Level "INFO" -Message "Path is invalid - $($sFile)" -logfile $mainLog
            }
        }
        else{
            $sUser = Read-Host -Prompt 'Enter user name (leave blank to exit)'
            if($sUser){
                Write-Host "Starting process for $($sUser)"
                if (Check-Username $sUser){
                    Write-Host  "$($sUser) - Cannot process name"
                    Write-Log -Level "INFO" -Message "$($sUser) - Cannot process name" -logfile $mainLog
                }
                else{
                    $params.user = $sUser
                    Process-User @params
                }
            }
            else{
                $exit = $true
            }
        }
    }
    While($exit -eq $false)
    Write-Log -Level "INFO" -Message "Exited While loop - Script Complete" -logfile $mainLog
}
$params.Add("usersFolders", $usersFolders)
Invoke-Main @params

