<#
.SYNOPSIS
    Generates either a CSV, scripts, or both from an XML exported from dfsutil /root:\\server\folder /export:filename.xml. The scripts generated are designed to remove the old links and create new links based on a provided server name.
.DESCRIPTION
    Generates either a CSV, scripts, or both from an XML exported from dfsutil /root:\\server\folder /export:filename.xml. The scripts generated are designed to remove the old links and create new links based on a provided server name.
.PARAMETER server
    Server name to replace the existing server name with for the migration script.  The script will check the provided server name to the DFS server names and only create replacement scripts based on the DFS server names which do not match.
.PARAMETER file
    The file parameters is the XML from dfsutil to process.   
.PARAMETER export
    Provides a custom name for the csv export.  By default the name is set to "dfsExport_YYYYMMddHHmmSS.csv" and is created in the same folder as the script.
.PARAMETER scripts
    Flag to determine if the script should create scripts based on the unique DFS folders in the export XML.  Each unique folder gets is own script to run, which removes the old DFS link and creates a new DFS link with the same share name to a new DFS target. 
.PARAMETER csv
    Flag to determine if the script should create a csv file of the DFS links from the processed XML file. 
.PARAMETER scriptsDir
    This paramter allows a custom directory for exporting the scripts.  If the directory does not exist it will be created.  By default, the scripts will be placed in a directory called "scripts_dfs" in the same folder as the main script. 
.EXAMPLE
    C:\PS> .\createCsvFromDfsXml.ps1.ps1 -file $pwd\data\dfsExport.xml -server \\sub.example.com -scripts -csv
    The example above will generate the scripts and csv files in the default locations based on a new DFS targer of sub.example.com with a XML file in the local folder named data.
.NOTES
    XML from dfsutil /root:\\server\folder /export:file.xml /verbose
    dfsutil link remove dfsLink
    dfsutil link add dfsLink dfsTarget  
#>



param (
    [string]$server = "",
    [string]$file = "",
    [string]$scriptsDir = "scripts_dfs",
    [string]$export = "dfsExport_$(get-date -f yyyyMMddHHmmss).csv",
    [switch]$scripts = $False,
    [switch]$csv = $False
)

$writeLogFunction = @'
Function Write-Log {
    [CmdletBinding()]
    Param(
    [Parameter(Mandatory=$False)]
    [ValidateSet("INFO","WARN","ERROR","FATAL","DEBUG")]
    [String]
    $Level = "INFO",
    [Parameter(Mandatory=$True)]
    [string]
    $Message,
    [Parameter(Mandatory=$False)]
    [string]
    $logfile
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    If($logfile) {
        Add-Content $logfile -Value $Line
    }
    Else {
        Write-Output $Line
    }
}

'@
$removeNewLineTab = @'
$out = $out.replace("`n", "").replace("`r","").replace("`t","")

'@
$startTimeScript = '$startTime = Get-Date' + "`n"
$endTimeScript = @'
$endTime = Get-Date 
$timeSpan = (New-Timespan -Start $startTime -End $endTime)
'@
$endTimeLog = "Write-Log -logfile $($folder.targetRootFolder)_dfs.log -Message `"`$(get-date -f yyyyMMddHHMMss) - Elapsed Time - Total Hours: `$(`$timeSpan.TotalHours); TotalMinutes: `$(`$timeSpan.TotalMinutes); Total Seconds: `$(`$timeSpan.TotalSeconds)`"`n"
$uncRegex = "^\\" 
$links = New-Object System.Collections.Generic.List[System.Object]
# $Path = "$($PSScriptRoot)\data\dfsExport.xml"

$srcObject = [PSCustomObject]@{
    dfsRoot          = ''
    dfsFolder        = ''
    targetServer     = ''
    targetRootFolder = ''
    targetFolderPath = ''
    dfsLinkRemove    = 'dfsutil link remove DFSLINK'
    dfsAddLink       = 'dfsutil link add DFSLINK DFSTARGET'
}

if (-Not ($scripts) -And -Not ($csv)) {
    throw "-csv or -scripts is required"
}

if (-Not [regex]::matches($server, $uncRegex)) {
    $server = "\\" + $server
}

if (-Not (Test-Path $scriptsDir)) {
    $results = New-Item -Path $scriptsDir -ItemType "directory"
}

# Write-Host "Server: $($server) - File: $($file) - Export: $($export)"
$xml = New-Object -TypeName XML
$xml.Load($file)

$root = $xml.Root.Name

# $root
$xml.Root.Link | ForEach-Object {
    $rootFolder = $_.Name
    if ($_.hasChildNodes) {
        # $_.ChildNodes | Select-Object -Property *
        $_.ChildNodes | ForEach-Object {
            
            $tempObj = $srcObject.psobject.Copy()
            $tempObj.dfsRoot = $root
            $tempObj.dfsFolder = $rootFolder
            $tempObj.targetServer = "\\" + $_.server

            $tempDfsLink = Join-Path -Path $tempObj.dfsRoot -ChildPath $tempObj.dfsFolder
            $tempObj.dfsLinkRemove = $tempObj.dfsLinkRemove.replace("DFSLINK", $tempDfsLink)
            
            if ($_.folder -Match "\\") {
                $splitFolder = $_.folder -split "\\"
                $tempObj.targetRootFolder = $splitFolder[0]
                $tempObj.targetFolderPath = $_.folder
            }
            else {
                $tempObj.targetRootFolder = $_.folder
                $tempObj.targetFolderPath = $_.folder
            }
            # $tempDfsTarget = Join-Path -Path $tempObj.targetServer $tempObj.targetRootFolder -ChildPath $tempObj.targetFolderPath
            $tempDfsTarget = [io.path]::combine($server, $tempObj.targetFolderPath)
            $tempObj.dfsAddLink = $tempObj.dfsAddLink.Replace("DFSLINK", $tempDfsLink).replace("DFSTARGET", $tempDfsTarget)
            # Write-Host $tempObj.dfsAddLink
            $links.add($tempObj)
        }
    }
}

if ($csv) {
    $links | Export-Csv -Path $export -NoTypeInformation
}


if ($scripts) {
    # $links | ft
    $uniqueRoots = $links | Sort-Object targetRootFolder -Unique | Select-Object -Property targetRootFolder
    $outVar = '$out'
    ForEach ($folder in $uniqueRoots) {
        # Write-Host $folder.targetRootFolder
        $scriptFile = Join-Path -Path $scriptsDir -ChildPath "$($folder.targetRootFolder)_dfs_Script_$(get-date -f yyyyMMddHHmmss).txt"
        $content = [System.Text.StringBuilder]::new()

        $endTimeLog = "Write-Log -logfile $($folder.targetRootFolder)_dfs.log -Message `"Elapsed Time - Total Hours: `$(`$timeSpan.TotalHours); TotalMinutes: `$(`$timeSpan.TotalMinutes); Total Seconds: `$(`$timeSpan.TotalSeconds)`"`n"


        ForEach ($link in $links) {
            if ($link.targetFolderPath -match $folder.targetRootFolder) {
                # $link | Select-Object -Property * 
                
                if (-Not $link.targetServer.contains($server)) {
                    # Write-Host "TargetServer: $($link.targetServer)`tTargetRoot: $($folder.targetRootFolder)`tDFS: $(Join-Path -Path $link.dfsRoot -ChildPath $link.dfsFolder)"
                    $sourceCommentLine = "Source DFS Link: $(Join-Path -Path $link.dfsRoot -ChildPath $link.dfsFolder); Source DFS Target: $(Join-Path -Path $link.targetServer -ChildPath $link.targetFolderPath)"
                    $writeLog = "Write-Log -logfile $($folder.targetRootFolder)_dfs.log -Message `"$($sourceCommentLine)`""
                    $checkLinkResults = "$($outVar) = (dfsutil link `"$(Join-Path -Path $link.dfsRoot -ChildPath $link.dfsFolder)`") | Out-String"
                    $writeResults = "Write-Log -logfile $($folder.targetRootFolder)_dfs.log -Message $($outVar)"
                    [void]$content.AppendLine("`# $($sourceCommentLine)")
                    [void]$content.AppendLine($writeLog)
                    [void]$content.AppendLine($link.dfsLinkRemove)
                    [void]$content.AppendLine($link.dfsAddLink)
                    [void]$content.AppendLine($checkLinkResults)
                    [void]$content.Append($removeNewLineTab)
                    [void]$content.AppendLine($writeResults)
                    
                    [void]$content.AppendLine("`n")
                }
            }
        }
        if ($content.Length -gt 0) {
            # Write-Host $writeLogFunction


            [void]$content.Insert(0, $startTimeScript, 1)
            [void]$content.Insert(0, $writeLogFunction, 1)
            [void]$content.AppendLine($endTimeScript)
            [void]$content.AppendLine($endTimeLog)
            Set-Content -Path $scriptFile -Value $content
        }
    }
}



