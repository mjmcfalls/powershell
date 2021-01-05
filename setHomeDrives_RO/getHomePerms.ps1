#Set server / path
$server = "\\server\usersHome"
$users = @("user1", "user2")
#Build Array with all the folder names to check
# $sites = @("users2")
$usersFolders = @("users","users2")
#Loop through each folder above and build full path to folder
$userDict = @{}
$results = New-Object System.Collections.Generic.List[System.Object]
$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
foreach ($folder in $usersFolders) {
    $folPath = $server + '\' + $folder
    
    #Look in each folder from above and get a list of all child folders
    $items = (Get-ChildItem $folPath -Directory).FullName
    # $items
    $userDict.Add($folder, $items)
}
$stopwatch.Stop()

# $userDict
$userStopWatch = [System.Diagnostics.StopWatch]::StartNew()

foreach ($folder in $usersFolders) {
    # $userDict.$($folder).getType()
    foreach ($unc in $userDict.$($folder)) {
        $tempObj = [PSCustomObject]@{
            user = $($unc.split("\")[-1])
            path = $unc
            FileSystemRights = $null
            IdentityReference = $null
            AccessControlType = $null
            InheritanceFlags = $null

        }
        $u = $($unc.split("\")[-1])
        # $tempObj.user = $u
        # $tempObj
        
        Try{
            $acl = Get-Acl $unc | Select-Object -ExpandProperty Access | Where-Object identityreference -match "$($u)"
            "$($unc): $($u) - $($acl.IdentityReference)"
            # "Length: $($acl.FileSystemRights.length)"
            if($acl.FileSystemRights.length -gt 1){
                $tempObj.FileSystemRights = $acl.FileSystemRights | Out-String
                # "FsRights: $($acl.FileSystemRights "
                $tempObj.IdentityReference = $acl.IdentityReference.Value | Out-String
                $tempObj.AccessControlType = $acl.AccessControlType | Out-String
                $tempObj.InheritanceFlags = $acl.InheritanceFlags | Out-String
            }
            elseif($acl.FileSystemRights.length -eq 1){
                # $acl
                $tempObj.FileSystemRights = $acl.FileSystemRights
                $tempObj.IdentityReference = $acl.IdentityReference
                $tempObj.AccessControlType = $acl.AccessControlType
                $tempObj.InheritanceFlags = $acl.InheritanceFlags
            }
            # else{
            #     $acl
            #     $tempObj.FileSystemRights = $acl.FileSystemRights | Out-String
            #     # "FsRights: $($acl.FileSystemRights "
            #     $tempObj.IdentityReference = $acl.IdentityReference | Out-String
            #     $tempObj.AccessControlType = $acl.AccessControlType | Out-String
            #     $tempObj.InheritanceFlags = $acl.InheritanceFlags | Out-String
            # }

        }
        Catch{
            Write-Host $_
        }
        # continue
        # $tempObj
        $results.Add($tempObj)
    }
}
$results | Export-Csv -NoTypeInformation "usersAcls.csv"

$userStopWatch.Stop()
Write-Host "Users generated $($userStopWatch.Elapsed.TotalMinutes)"
Write-Host "Generate hash table time: $($stopwatch.Elapsed.TotalMinutes)"
