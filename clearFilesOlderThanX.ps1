[CmdletBinding(
    SupportsShouldProcess = $True
)]
param (
    [String[]]$path = @("E:\path1\logs", "E:\path2\logs", "E:\path3\logs"),
    [int]$days = -90,
    [string]$LogFile = "c:\admin\LogFileDeletions.log"
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

Function Test-LogPath {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    param (
        [string]$LogFile
    )
    If(-Not (Test-Path -Path (Split-Path -Path $LogFile))){
        New-Item -ItemType Directory -path $logfile
    }
}

Function Invoke-Main {
    [CmdletBinding(
        SupportsShouldProcess = $True
    )]
    param (
        [string]$path,
        [int]$days,
        [string]$LogFile
    )

    $files = $null
    Test-LogPath -LogFile $LogFile
    
    $files = Get-ChildItem $path -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -le ((Get-Date).AddDays($days)) } 

    Write-Log -Level "INFO" -Message "Found $($files.count) files older than $([Math]::Abs($days)) days in $($path)" -logfile $LogFile

    if($files){
        ForEach ($file in $files) {
            Write-Log -Level "INFO" -Message "Deleted: $($file.fullname)" -logfile $LogFile
            Remove-Item -Path "$($file.fullname)" -Force
        }
    }
    $files
}

foreach($p in $path){
    $results = Invoke-Main -path $p -days $days -LogFile $LogFile
    Write-Log -Level "INFO" -Message "Completed!!" -logfile $LogFile
}




