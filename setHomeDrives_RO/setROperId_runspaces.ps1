
[CmdletBinding(
    SupportsShouldProcess = $True
)]
param(
    [string]$user
)

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
#Set server / path
$server = "\\server\userHomess"
$users = @("user1")
#Build Array with all the folder names to check
# $sites = @("users2")
$usersFolders = @("users", "users2", "users3")
#Loop through each folder above and build full path to folder
$userDict = @{}


# foreach ($folder in $usersFolders) {
#     $folPath = $server + '\' + $folder
    
#     #Look in each folder from above and get a list of all child folders
#     $items = (Get-ChildItem $folPath -Directory).FullName
#     # $items
#     $userDict.Add($folder, $items)
# }

function Find-User {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    param(
        [string]$user,
        [string]$rootFolder,
        [string]$userFolder
    )
    $searchFolders = (Get-ChildItem (Join-Path -Path $rootFolder -ChildPath $userFolder) -Directory).FullName
    Foreach ($folder in $searchFolders) {
        if ($folder -match "$($user)") {
            Write-Output "$($user) found in $($folder)"
            break
        }
    }
}
# # $userDict
# foreach ($user in $users) {
#     # $userStopWatch = [System.Diagnostics.StopWatch]::StartNew()

#     foreach ($folder in $usersFolders) {
#         # $userDict.$($folder).getType()
#         foreach ($unc in $userDict.$($folder)) {
#             # $unc
#             if ($unc -match "$($user)") {
#                 # $userDict.$($folder)
#                 "$($user) found in $($folder)"
#                 # Get-Acl $unc | Select-Object -ExpandProperty Access | Where-Object identityreference -like "*$($user)*"
#                 $userStopWatch.Stop()
#                 Write-Host "User found in $($userStopWatch.Elapsed.TotalMinutes)"
#             }
#         }
#     }
# }
# $stopwatch.Stop()
# Write-Host "Found user account in: $($stopwatch.Elapsed.TotalMinutes)"


$Scriptblock = {
    param(
        [string]$user,
        [string]$rootFolder,
        [string]$userFolder
    )
    # New-Item -Name $Name -ItemType File
    # Write-Output "$($user) - $(Join-Path -Path $rootFolder -ChildPath $userFolder)"
    Write-Output (Find-User $user $rootFolder $userFolder)
}

$MaxThreads = $usersFolders.Length
$jobs = New-Object System.Collections.ArrayList
$findUserDef = Get-Content function:\Find-User
# $findUserDef
$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$findUserEntry = New-Object System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList "Find-User", $findUserDef
# $findUserEntry
$SessionState.Commands.Add($findUserEntry)
# $SessionState.Commands
$RunspacePool = [runspacefactory]::CreateRunspacePool($SessionState)

[void]$RunspacePool.SetMinRunspaces(1)
[void]$RunspacePool.SetMaxRunspaces($MaxThreads) 
$RunspacePool.Open()


Foreach ($userFolder in $usersFolders) {
    # "Adding $($userFolder)"
    $parameters = @{
        "user" = "user1"
        "rootFolder" = $server
        "userFolder" = $userFolder
    }
    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $RunspacePool
    [void]$PowerShell.AddScript($ScriptBlock)
    [void]$Powershell.AddParameters($parameters)
    # $PowerShell
    [void]$jobs.Add((
            [pscustomobject]@{
                PowerShell = $PowerShell
                Handle     = $PowerShell.BeginInvoke()
            }
        ))
}

while ($jobs.Handle.IsCompleted -contains $false ) {
    # Write-Host "." -NoNewline
    Start-Sleep -Milliseconds 100

}

ForEach ($job in $jobs ) {
    $job.powershell.EndInvoke($job.handle)
    $job.PowerShell.Dispose()
}

$RunspacePool.Close()

$stopwatch.Stop()
Write-Host "[Runspace pool $($maxThreads)] User found in`n"
$stopwatch.Elapsed
