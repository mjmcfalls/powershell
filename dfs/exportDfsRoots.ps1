
param (
    [string]$server = ""
)

$uncRegex = '^\\'
$servers = New-Object System.Collections.Generic.List[System.Object]
$dfsRoots = dfsutil server $($server) | Out-String
$dfsRoots = ($dfsRoots.split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)).replace("`t", "")
# $dfsRoots
Foreach ($row in $dfsRoots) {
    if ($row -match $uncRegex) {
        Write-Host "Processing $($row)"
        $splitRow = $row.split("\")
        # Write-Host (Join-Path -Path $splitRow[1] -ChildPath $splitRow[2])
        dfsutil /root:"$(Join-Path -Path $splitRow[1] -ChildPath $splitRow[2])" /export:"exports\$($splitRow[1] + "_" + $splitRow[2]).xml" | Out-Null
    }

}
