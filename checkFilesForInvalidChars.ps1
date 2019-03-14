param([String]$path=$null)

$invalidChars = [System.IO.Path]::GetInvalidFileNameChars() -join ''

$invalidCharsRegex = [regex]::Escape($invalidChars) 
$trailingSpaceRegex = [regex]::new("(?<=\S)\s+$")

if( -not $path){
    throw "No Path specified!"
}


Get-ChildItem -Path c:\ -Recurse | ForEach-Object{
    $name = $_.Name
    $rename = $false
    # Write-Host "Checking $($name)"
    if($name.contains($invalidCharsRegex)){
        Write-Host "$($name) contains invalid charaters"
        $name = $name -replace $invalidCharsRegex
        $rename = $true 
    }

    if($name.contains($trailingSpaceRegex)){
        Write-Host "$($name) contains trailing space."
        $name = $name -replace $trailingSpaceRegex
        $rename = $true 
    }
    if($rename){
        Write-Host "Renaming $($_.FullName) to $($name)"
        # Rename-Item -Path $_.FullName -Newname $name
    }
    
}
