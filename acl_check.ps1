param (
    [string]$dir = $null,
    [string]$user = "Domain Admins",
    [switch]$force = $false
)

Function add-Perms {
    param(
        # [Parameter(Mandatory = $True, Position = 0)]
        # [ValidateNotNullOrEmpty()]
        # $userExists, 
        [Parameter(Mandatory = $True, Position = 0)]
        [ValidateNotNullOrEmpty()]
        $permsExist,
        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        $directory,
        [Parameter(Mandatory = $True, Position = 2)]
        [ValidateNotNullOrEmpty()]
        $user,
        [Parameter(Mandatory = $True, Position = 3)]
        [ValidateNotNullOrEmpty()]
        $targetPerms
    )
    begin {
        # Write-Host ("Running add-Perms")
    }
    process {
        # write-Host "PermsExists: $($permsExist)"
        if ($permsExist) {
            # Write-Host ("$($directory) - Already Exists $($targetPerms) for $($user)") 
            
        } 
        else {
            Write-Host ("No Perms: $($directory) - Add $($targetPerms) for $($user)")
            #     $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($user, $targetPerms, "Allow")
            #     $acl.SetAccessRule($AccessRule)
            #     $acl.SetAccessRuleProtection($false,$true)
            #     Set-Acl -Path $directory -AclObject $acl
            # }
            # if ($userExists -And -Not ($permsExists)) {
            #     Write-Host ("User, Not Perms: $($directory) - Add $($targetPerms) for $($user)")
        }
    }
}




# $userExists = $False
# $permsExist = $False
$targetPermissions = "FullControl"
if (-not $dir) {
    Write-Host "Please provide a directory or file to check."
}
$count = 0
$startTime = Get-Date
# Write-Host "$(get-date -f yyyyMMddHHMMss) - Start Time: $($startTime)"
$rootDirectories = Get-ChildItem -path $dir -Directory
$countRootDirs = $rootDirectories.length
$rootDirectories | ForEach-Object {
    $rootPerms = $False
    # Write-Host "Checking Root Directory: $($_.FullName)"
    $acl = Get-acl -Path $_.FullName
    ForEach ($a in $acl.Access) {
        # write-Host "$($_.FullName) - IdentityReference: $($a.IdentityReference) - FileSystemRights: $($a.FileSystemRights)"
        if ($a.IdentityReference -Match $user) {
            # Write-Host "$($_.FullName) - $($user) - User exist"
            if ($a.FileSystemRights -Match $targetPermissions) {
                # Write-Host "$($_.FullName) - $($user) - Perms exist"
                $rootPerms = $True
            }
        }
    }
    if ($rootPerms) {
        $count += 1
        add-Perms $rootPerms $_.FullName $user $targetPermissions
    }
    
}

# $rootDirectories = Get-ChildItem -path $dir -Directory
# $rootDirectories | ForEach-Object {
#     Write-Host "Checking child folders of $($_.FullName)"
#     $files = Get-ChildItem -path $_.FullName -Directory -Recurse
#     $files | ForEach-Object {
#         # Write-Host "Checking: $($_.FullName)"
#         # $userExists = $False
#         $permsExist = $False
#         $acl = Get-acl -Path $_.FullName
#         ForEach ($a in $acl.Access) {
#             # write-Host "$($_.FullName) - IdentityReference: $($a.IdentityReference) - FileSystemRights: $($a.FileSystemRights)"
#             if ($a.IdentityReference -Match $user) {
#                 # Write-Host "$($_.FullName) - $($user) - User exist"
#                 if ($a.FileSystemRights -Match $targetPermissions) {
#                     # Write-Host "$($_.FullName) - $($user) - Perms exist"
#                     $permsExist = $True
#                 }
#                 # else {
#                 #     $permsExist = $False
#                 # }
#             }
#         }

#         add-Perms $permsExist $_.FullName $user $targetPermissions 
#     }
# }

Write-Host "$($count) of $($countRootDirs)  root directories needed changes"
$endTime = Get-Date
$timeSpan = (New-Timespan -Start $startTime -End $endTime)
Write-Host "$(get-date -f yyyyMMddHHMMss) - Elapsed Time - Total Hours: $($timeSpan.TotalHours); TotalMinutes: $($timeSpan.TotalMinutes); Total Seconds: $($timeSpan.TotalSeconds)"
# FileSystemRights  : FullControl
# AccessControlType : Allow
# IdentityReference : BUILTIN\Administrators
# IsInherited       : True
# InheritanceFlags  : None
# PropagationFlags  : None
