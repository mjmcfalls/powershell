param([String]$path = $null)

$invalidChars = [System.IO.Path]::GetInvalidFileNameChars() -join ''

$invalidCharsRegex = [regex]::Escape($invalidChars) 
# $trailingSpaceRegex = [regex]::new("\s+$")
[regex]$dirRegex = '[dD](irectory)'

if ( -not $path) {
    throw "No Path specified!"
}

Write-Host "Getting root directores in $($path)"
try {
    $directories = Get-ChildItem -Path $path 2> $outnull
    if (-not $?) {
        #whatever action you want to perform
        $msg = $msg + "Error accessing " + $dir + ": " + $error[0].Exception.Message
    }

}
catch {
    $msg = "Error accessing " + $dir + ": " + $_.Exception.Message
}


$directories | Sort-Object | ForEach-Object {
    Write-Host "Checking $($_.FullName)"
    if ($dirRegex.Match($_.Attributes)) {
        $files = Get-ChildItem -Path $_.FullName -Recurse
        Foreach ($file in $files) {
            $name = $file.Name
            $rename = $false
            # Write-Host "Checking $($name)"
            if ($name.contains($invalidCharsRegex)) {
                Write-Host "$($name) contains invalid characters"
                # $name = $name -replace $invalidCharsRegex
                $rename = $true 
            }
        
            # if ($name.contains($trailingSpaceRegex)) {
            #     Write-Host "$($name) contains trailing space."
            #     $name = $name -replace $trailingSpaceRegex
            #     $rename = $true 
            # }
            if ($rename) {
                Write-Host "Renaming $($file.FullName) to $($name)"
                # Rename-Item -Path $_.FullName -Newname $name
            }
        }
    }
    else {
        if ($_.Name.contains($invalidCharsRegex)) {
            Write-Host "$($name) contains invalid characters"
            # $name = $name -replace $invalidCharsRegex
            $rename = $true 
        }
    }
}
