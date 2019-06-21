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

Function Remove-LongPathNames {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    Param(
        [string]$Path
    )

    if ($_.FullName.length -ge 200) {
        if (-Not $_.FullName.StartsWith("\\?\UNC")) {
            $Path = "\\?\UNC" + $_.FullName.Substring(1)
        }
    }

    if ( $_.PSIsContainer) {
        if ((Get-ChildItem -LiteralPath "$($Path)" -Force | Select-Object -First 1 | Measure-Object).Count -eq 0) {
            # Folder is empty; Remove folder
            Remove-Item -LiteralPath "$($Path)" -Force 
        }
        else {
            Write-Warning "Not Empty: $($Path)"
        }
    }
    else {
        # If not a directory.
        Remove-Item -LiteralPath "$($Path)" -Force
    }
}

Function Clean-Dirs {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    Param(
        [string]$Path,
        [switch]$Directory = $False
    )

    if ($Path.length -ge 160) {
        $Path = "\\?\UNC" + $Path.Substring(1)
    }
    if ($Directory) {
        # Write-Host "Directory flag found"
        Try {
            # Write-Host 'Try getting child dirs.'
            Get-ChildItem -LiteralPath "$($Path)" -Force -Directory -Recurse -ErrorAction "Stop" | 
            Sort-Object -Property @{Expression = "FullName"; Descending = $True } |
            ForEach-Object {
                Write-Host "Dir: $($_.FullName)"
                Remove-LongPathNames $_.FullName
            }
        }
        Catch [System.IO.DirectoryNotFoundException] {
            # Write-Host "dir deleting error"
            $Path = "\\?\UNC" + $Path.Substring(1)
            Get-ChildItem -LiteralPath "$($Path)" -Force -Directory -Recurse | 
            Sort-Object -Property @{Expression = "FullName"; Descending = $True } |
            ForEach-Object {
                Write-Host "Dir: $($_.FullName)"
                Remove-LongPathNames $_.FullName
            }
        }
        Write-Host "Dir: $($Path)"
        Remove-LongPathNames "$($Path)"
    }
    else {
        Try {
            Get-ChildItem -LiteralPath "$($Path)" -Force -Recurse -File -ErrorAction "Stop" |
            Where-Object { -Not $_.PSIsContainer } | 
            Sort-Object -Property  @{Expression = "FullName"; Descending = $True } |
            ForEach-Object {
                If (-Not $_.PSIsContainer) {
                    # Remove Files
                    Write-host "File: $($_.FullName)"
                    Remove-LongPathNames $_.FullName
                }
            }
        }
        Catch [System.IO.DirectoryNotFoundException] {
            $Path = "\\?\UNC" + $Path.Substring(1)
            # Write-Host "Catch file exception - new path: $($Path)"
            Get-ChildItem -LiteralPath "$($Path)" -Force -File -Recurse |
            Where-Object { -Not $_.PSIsContainer } | 
            Sort-Object -Property  @{Expression = "FullName"; Descending = $True } |
            ForEach-Object {
                If (-Not $_.PSIsContainer) {
                    # Remove Files
                    Write-host "File: $($_.FullName)"
                    Remove-LongPathNames $_.FullName
                }
            }
        }
    }
}

$StartTime = Get-Date
$TargetDate = (Get-Date).AddDays( - ($Days))
$CountRemovedDirs = 0

# Filter out directories not older than $days, and sort by PSIContainer, the Full Path Name.
Get-ChildItem -Path $Path -Force -Directory | 
Where-Object { $_.LastWriteTime -lt $TargetDate } | 
Sort-Object -Property @{Expression = "PSIsContainer"; Descending = $False }, @{Expression = "FullName"; Descending = $False } |
ForEach-Object {
    Clean-Dirs -Path $_.FullName
    Clean-Dirs -Path $_.FullName -Directory
    $CountRemovedDirs += 1
}

Write-Host "Removed $($CountRemovedDirs) directories."

$EndTime = Get-Date
$TimeSpan = (New-Timespan -Start $StartTime -End $endTime)
Write-Log -Level "INFO" -Message "Elapsed Time - Total Hours: $($TimeSpan.TotalHours); TotalMinutes: $($TimeSpan.TotalMinutes); Total Seconds: $($TimeSpan.TotalSeconds)" -logfile $LogFile
Write-Host "$(get-date -f yyyyMMddHHMMss) - Elapsed Time - Total Hours: $($TimeSpan.TotalHours); TotalMinutes: $($TimeSpan.TotalMinutes); Total Seconds: $($TimeSpan.TotalSeconds)"
