[CmdletBinding(
    SupportsShouldProcess = $True
)]
param(
    [String]$File = "",
    [String]$Server = "",
    [String]$LogFile = ""
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

# [regex]$errRegex = '(ERROR)|(WARNING)'
[regex]$ErrRegex = '(ERROR \([0-9]+\))'
[regex]$InUseRegex = '(ERROR \(32\))'
[regex]$UncRootRegex = '\\\\.*?(\\)'
# [regex]$UncRegex = '\\\\\w+[\.\w\\ `#~\$+-]+(?! ->)'
$UncRegex = '^\\\\'

if ($Server -NotMatch $UncRegex) {    
    $Server = "\\" + $Server
}

if ( -not $File) {
    throw "No Path specified!"
}


$Content = Get-Content $File
$FilteredContent = [System.Text.StringBuilder]::new()
Foreach ($row in $Content) {
    if ([string]::IsNullOrWhiteSpace($row)) {
    }
    else {
        if ($ErrRegex.Match($row).Success) {
            
            $matches = $ErrRegex.Match($row)

            if ($InUseRegex.Match($matches).Success) {
                $SplitError = $row -split ":"

                $Unc = ($($SplitError[-1] -split "->")[0]).trim()
                $UncSplit = $Unc -split $UncRootRegex

                $NewUnc = Join-Path -Path $Server -ChildPath $UncSplit[-1]

                if (Test-Path $Unc) {
                    Try {
                        Write-Host "Copy $($Unc) to $($NewUnc)`n"
                        # Write to log file
                        Copy-Item "$($Unc)" "$($NewUnc)" -Force
                        Write-Log -logfile $LogFile -Level "INFO" -Message "Copy $($Unc) to $($NewUnc)"
                    }
                    Catch {
                        Write-Warning "$($_)"
                        Write-Log -logfile $LogFile -Level "ERROR" -Message "Copy $($Unc) to $($NewUnc) - $($_)"
                    }
                    Finally {
                        
                    }

                }
                else {
                    # Write to log that file does not exist
                    Write-Log -logfile $LogFile -Level "WARN" -Message "Does not exist: $($Unc)"
                }

            }
        }
    } 
}
