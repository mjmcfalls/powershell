param([String]$path = $null)

$invalidChars = [System.IO.Path]::GetInvalidFileNameChars() -join ''

$invalidCharsRegex = [regex]::Escape($invalidChars) 
# $trailingSpaceRegex = [regex]::new("\s+$")

if ( -not $path) {
    throw "No Path specified!"
}

Write-Host "Checking files and folders in $($path)."
try {
    $files = Get-ChildItem -Path $path -Recurse 2> $outnull
    if (-not $?) {
        #whatever action you want to perform
        $msg = $msg + "Error accessing " + $dir + ": " + $error[0].Exception.Message
    }

}
catch {
    $msg = "Error accessing " + $dir + ": " + $_.Exception.Message
}


$files | ForEach-Object {
    $name = $_.Name
    $rename = $false
    # Write-Host "Checking $($name)"
    if ($name.contains($invalidCharsRegex)) {
        Write-Host "$($name) contains invalid charaters"
        $name = $name -replace $invalidCharsRegex
        $rename = $true 
    }

    # if ($name.contains($trailingSpaceRegex)) {
    #     Write-Host "$($name) contains trailing space."
    #     $name = $name -replace $trailingSpaceRegex
    #     $rename = $true 
    # }
    if ($rename) {
        Write-Host "Renaming $($_.FullName) to $($name)"
        # Rename-Item -Path $_.FullName -Newname $name
    }
    
}
