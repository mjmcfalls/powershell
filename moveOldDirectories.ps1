[CmdletBinding(
    SupportsShouldProcess = $True
)]
param(
    [int]$Days = 30,
    [String]$Path = "",
    [String]$TargetPath = "",
    [String]$LogFile = "MovedFiles.log"
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

$StartTime = Get-Date
$ExcludeDirs = @("Docs", "fincfx", "_ToDelete")
$TargetDate = (Get-Date).AddDays( - ($Days))

# Move Directories created over $days days ago
Get-ChildItem -Directory -Path $Path | Sort-Object | Foreach {
    if ($ExcludeDirs -contains $_.Name) {
        Write-Host "Skipping $($_.FullName)"
        Write-Log -Level "WARN" -Message "Skipping $($_.FullName)" -logfile $LogFile

    }
    else {
        if ( $_.LastWriteTime -lt $TargetDate) {
            # Write-Host "Processing $($_.FullName)"
            # $_ | Select-Object -Property *
            Write-Log -Level "INFO" -Message "Moving $($_.Name) to $(Join-Path -Path $TargetPath -ChildPath $_.Name)" -logfile $LogFile
            Write-Host "Moving $($_.Name) to $(Join-Path -Path $TargetPath -ChildPath $_.Name)"
            Move-Item $_.FullName (Join-Path -Path $_.PSParentPath -ChildPath $_.Name)
        }
    }
}

$EndTime = Get-Date
$TimeSpan = (New-Timespan -Start $StartTime -End $endTime)
Write-Log -Level "INFO" -Message "Elapsed Time - Total Hours: $($TimeSpan.TotalHours); TotalMinutes: $($TimeSpan.TotalMinutes); Total Seconds: $($TimeSpan.TotalSeconds)" -logfile $LogFile
Write-Host "$(get-date -f yyyyMMddHHMMss) - Elapsed Time - Total Hours: $($TimeSpan.TotalHours); TotalMinutes: $($TimeSpan.TotalMinutes); Total Seconds: $($TimeSpan.TotalSeconds)"