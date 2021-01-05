[CmdletBinding(
    SupportsShouldProcess = $True
)]
param(
    [string]$file = "\\server\Path\To\\exportedUserPaths.txt",
    [string]$server = '\\server\userHomes'
)

$usersFolders = @("users", "users2", "users3")

$params = @{}

Foreach ($key in $MyInvocation.MyCommand.Parameters.GetEnumerator()) {
    $k = $key.key
    $val = Get-Variable $k -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Value 
    if ($val) {
        $params.Add($k, $val)
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
    $userDict =  [System.Collections.ArrayList]@()
    foreach ($folder in $usersFolders) {
        $folPath = Join-Path -Path $server -ChildPath $folder
        # $folPath
        $items = (Get-ChildItem $folPath -Directory).FullName #| Split-Path -Leaf
        # $items
        [void]$userDict.Add($items)
    }
    $userDict
}

$folders = Get-Folders -server $server -usersfolders $usersFolders
$folders | Set-Content $file