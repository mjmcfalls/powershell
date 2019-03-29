param (
    [string]$server = ""
)


$results = (dfsutil link "`"$($server)`"") | Out-String
$resultsHash = @{}
[regex]$pattern = "State"
if ($results) {
    # $results = ($results.split([Environment]::NewLine, [StringSplitOptions]::RemoveEmptyEntries)).replace("`t", "")
    $results = $pattern.replace($results, "Status", 1)
    $splitResults = ([regex]::split($results, "(?:`"\s+)")).replace("`n", "").replace("`r", "").replace("`t", "")
    # $splitResults
    ForEach ($row in $splitResults) {
        # Write-host "$($row) - $($row -match '=')"
        if ($row -match '=') {
            $row = $row.replace("`"", "")
            # Write-Host "$($row)"
            $rowSplit = $row.split("=")
            # $rowSplit
            $resultsHash.Add($rowSplit[0], $rowSplit[1])
        }
    }
    
}

$resultsHash
