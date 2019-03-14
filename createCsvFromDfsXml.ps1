# XML from dfsutil /root:\\server\folder /export:file.xml /verbose
# dfsutil link remove dfsLink
# dfsutil link add dfsLink dfsTarget
$links = New-Object System.Collections.Generic.List[System.Object]
$Path = "$($PSScriptRoot)\data\dfs_export_20190311.xml"

$srcObject = [PSCustomObject]@{
    dfsRoot          = ''
    dfsFolder        = ''
    targetServer     = ''
    targetRootFolder = ''
    targetFolderPath = ''
    dfsLinkRemove    = 'dfsutil link remove DFSLINK'
    dfsAddLink       = 'dfsutil link add DFSLINK DFSTARGET'
}

$xml = New-Object -TypeName XML
$xml.Load($Path)

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
            $tempDfsTarget = [io.path]::combine($tempObj.targetServer, $tempObj.targetRootFolder , $tempObj.targetFolderPath)
            $tempObj.dfsAddLink = $tempObj.dfsAddLink.Replace("DFSLINK", $tempDfsLink).replace("DFSTARGET", $tempDfsTarget)
            $links.add($tempObj)
        }
    }
}


$links | Export-Csv -Path .\test.csv -NoTypeInformation
