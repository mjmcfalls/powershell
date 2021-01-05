[CmdletBinding()]
param(
    $file = "emailBreakdown.txt"
)

Function Check-ChildFolders {
    [CmdletBinding()]
    Param(
        $folder,
        $folderView,
        $itemView,
        $service
    )
    # Write-Host "Checking child Folder"
    # Write-Host "Check-ChildFolders Folder: $($folder.DisplayName)"
    $folderEmailArray = New-Object System.Collections.Generic.List[System.Object]
    
    # if ($folder.ChildFolderCount -gt 0) {
    $cFolders = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service, $folder.Id)
    $folds = $cFolders.FindFolders($folderView)
    foreach ($fold in $folds) {
        $returnedFoldArray = Check-ChildFolders $fold $folderview $itemView $service
        
        if ($returnedFoldArray) {
            # Write-Host "returnedFoldArray: $($returnedFoldArray.GetType())"
            ForEach ($email in $returnedFoldArray) {
                # Write-host $email.GetType()
                $folderEmailArray.Add($email)
            }
            # $folderEmailArray.Add($returnedFoldArray)
        }
    }
    $returnRootEmailArray = Get-MailItems $folder $ivItemView
    
    if ($returnRootEmailArray) {
        ForEach ($email in $returnRootEmailArray) {
            $folderEmailArray.Add($email)
        }
        # Write-Host "returnRootEmailArray: $($returnRootEmailArray.GetType())"
        
    }
   
    return $folderEmailArray
}

Function Get-MailItems {
    Param(
        $folder,
        $itemView
    )
    $localEmailArray = New-Object System.Collections.Generic.List[System.Object]
    
    $fiItems = $service.FindItems($folder.Id, $itemView)
    Write-Host "$($folder.DisplayName):$($fiItems.Items.count)"
    Add-Content -path $file -Value "$($folder.DisplayName):$($fiItems.Items.count)" 
    return $fiItems.Items.count 
}

# Set config.xml path
$configFile = "C:\folder\with\config.xml"
# Import Configuration xml file
$config = New-Object -TypeName XML
$config.Load($configFile)

$emailArray = New-Object System.Collections.Generic.List[System.Object]
# System.Collections.ArrayList
$PathToSearch = "\" 
$uri = $config.configuration.appSettings['uri'].InnerText
# $MailboxName = $config.configuration.appSettings['MailboxName'].InnerText
$MailboxName = "Root"
$user = $config.configuration.appSettings['user'].InnerText
$pass = $config.configuration.appSettings['pass'].InnerText
$dllpath = $config.configuration.appSettings['dllpath'].InnerText
$logFile = $config.configuration.appSettings['logFile'].InnerText
# $outCsv = $config.configuration.appSettings['outFile'].InnerText
$FolderName = @(($config.configuration.appSettings['getFolders'].InnerText) -split ",")

$EWSServicePath = $dllpath
Import-Module $EWSServicePath

if (!$PSScriptRoot) {
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent 
}

$ExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013
$service = new-object Microsoft.Exchange.WebServices.Data.ExchangeService($ExchangeVersion)
$psCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, (Get-Content $pass | ConvertTo-SecureString)
$creds = New-Object System.Net.NetworkCredential($psCred.UserName.ToString(), $psCred.GetNetworkCredential().password.ToString())    
$service.Credentials = $creds 
$PropertySet = New-Object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)
$PropertySet.RequestedBodyType = [Microsoft.Exchange.WebServices.Data.BodyType]::Text
# $PropertySet.RequestedBodyType = [Microsoft.Exchange.WebServices.Data.BodyType]::HTML

$service.Url = new-object Uri($uri)

$ivItemView = New-Object Microsoft.Exchange.WebServices.Data.ItemView(2000)  
$folderView = New-Object Microsoft.Exchange.WebServices.Data.Folderview(1000)
#Bind to the MSGFolder Root 
# $folderid = new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot, $MailboxName)
$rootFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service, [Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot)

$folders = $rootFolder.FindFolders($folderView)

foreach ($folder in $folders) {
    # $folder.DisplayName
    if ($folder.DisplayName -notin ("Conversation History", "Drafts")) {
        $returnedArray = Check-ChildFolders $folder $folderView $ivItemView $service
        if ($returnedArray) {
            $emailArray.Add($returnedArray)
        }
    }
}


# $emailArray | ConvertTo-Json  -Compress | Out-File ( $outPath -replace ".csv", ".json")
# $emailArray | ConvertTo-Json | Out-File ( $outPath )
$sum = 0
$emailArray | Foreach {
    # $sum += $_
    # $_.GetType()
    ForEach ($item in $_) {
        $sum += $item
    }

}

Write-Host "Number of Emails exported: $($sum)"