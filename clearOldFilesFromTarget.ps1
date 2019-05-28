[CmdletBinding(
    SupportsShouldProcess = $True
)]
param(
    [int]$Days = 30,
    [String]$Path = "",
    [String]$LogFile = "RemovedFiles.log"
)

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

Function Process-Directory {
    Param(
        [string]$Path,
        [string]$LogFile
    )
    $dirs = Get-ChildItem -Recurse -Path $Path
    ForEach ($dir in $dirs) {
        # Write-Host $dir
        if (-Not $dir.PSIsContainer) {
            Try {
                if ($dir.FullName.length -ge 260) {
                    # Write-Host "$($dir.FullName.length) - $($dir.FullName)"
                    # $dir | Select-Object -Property *
                    # Write-Host "$(Split-Path -Path $dir.Directory)"
                    $subDir = Get-ChildItem -LiteralPath ("\\?\UNC" + $dir.Directory.Substring(1))
                    # $subDir
                    Get-ChildItem $subDir -Recurse | ForEach {
                        Write-Host "Removing $($_.FullName)"
                        Write-Log -Level "INFO" -Message "Removed: $($_.FullName)" -logfile $LogFile
                        Remove-Item $_.FullName -Force
                    }
                    # .Directory or PSParentPath
                }
                else {
                    Write-Host "Removing: $($dir.FullName)"
                    Remove-Item $dir.FullName -Force
                }
                Write-Log -Level "INFO" -Message "Removed: $($dir.FullName)" -logfile $LogFile
            }
            Catch {
                Write-Log -Level "ERROR" -Message $_ -logfile $LogFile
            }
        }
    }
}
$StartTime = Get-Date
$ExcludeDirs = @("Docs", "fincfx")
$TargetDate = (Get-Date).AddDays( - ($Days))
$CountRemovedDirs = 0
# Check each directory to see if it is older than $days; if so delete all items in folder
Get-ChildItem -Directory -Path $Path | Sort-Object | Foreach {
    
    if ($ExcludeDirs -contains $_.Name) {
        Write-Host "Skipping $($_.FullName)"
    }
    else {
        if ( $_.LastWriteTime -lt $TargetDate) {
            Write-Host "$($_.LastWriteTime) - $($TargetDate) - $($_.FullName)"
            # Write-Host "Processing $($_.FullName)"
            Process-Directory -Path $_.FullName -LogFile $LogFile
            $CountRemovedDirs += 1
        }
        else {
            Write-Host "$($_.FullName) is less than $($Days) old; LastWriteTime: $($_.LastWriteTime)"
            Write-Log -Level "INFO" -Message "$($_.FullName) is less than $($Days) old; LastWriteTime: $($_.LastWriteTime)" -logfile $LogFile
        }
    }
}

if ($CountRemovedDirs -gt 0) {
    Write-Host "Removing Empty directories"
    Get-ChildItem -Path $Path -Recurse -Force | 
    Where-Object { $_.PSIsContainer -and (Get-ChildItem -Path $_.FullName -Recurse -Force | 
            Where-Object { !$_.PSIsContainer }) -eq $null } | Remove-Item -Force -Recurse
}
else {
    Write-Log -Level "INFO" -Message "No directories removed; skilling empty directory removals."
}

$EndTime = Get-Date
$TimeSpan = (New-Timespan -Start $StartTime -End $endTime)
Write-Log -Level "INFO" -Message "Elapsed Time - Total Hours: $($TimeSpan.TotalHours); TotalMinutes: $($TimeSpan.TotalMinutes); Total Seconds: $($TimeSpan.TotalSeconds)" -logfile $LogFile
Write-Host "$(get-date -f yyyyMMddHHMMss) - Elapsed Time - Total Hours: $($TimeSpan.TotalHours); TotalMinutes: $($TimeSpan.TotalMinutes); Total Seconds: $($TimeSpan.TotalSeconds)"
