[CmdletBinding()]
param(
    $file = "email.csv",
    $downloadDir
)

Function Check-ChildFolders {
    [CmdletBinding()]
    Param(
        $folder,
        $folderView,
        $itemView,
        $service,
        $downloadDir
    )
    # Write-Host "Checking child Folder"
    # Write-Host $folder.Id
    $folderEmailArray = New-Object System.Collections.Generic.List[System.Object]
    
    $cFolders = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service, $folder.Id)
    $folds = $cFolders.FindFolders($folderView)
    foreach ($fold in $folds) {
        # $fold
        if ($fold.TotalCount -gt 0) {
            # Write-Host "FolderEmailArray Count: $($folderEmailArray.count)"
            Write-Debug "$($fold.DisplayName); Msg Count: $($fold.TotalCount); Child Folders: $($fold.ChildFolderCount)"
            if ($fold.ChildFoldercount -gt 0) {
                # Write-Host $cFolder.DisplayName
                $returnedFoldArray = Check-ChildFolders $fold $folderview $itemView $service $downloadDir
               
            }
            $returnedMailArray = Get-MailItems $fold $ivItemView $downloadDir
            # if($returnedArray.Count -gt 0){
            # $folderEmailArray = $folderEmailArray + $returnedMailArray + $returnedFoldArray
            if ($returnedMailArray) {
                $folderEmailArray.AddRange($returnedMailArray)
            }
            
            if ($returnedFoldArray) {
                $folderEmailArray.AddRange($returnedFoldArray)
            }
            
            Write-Debug "FolderEmailArray Count: $($folderEmailArray.count)"
            # }
        }
    }
    return $folderEmailArray
}

Function Get-Attachments {
    Param(
        $item,
        $downloadDir 
    )
    if ($item.hasAttachments) {
        if (-Not (Test-Path $downloadDir -PathType Container)) {
            New-Item -ItemType Directory -Force -Path $downloadDir #| Out-Null
        }

        foreach ($attach in $Item.Attachments) {
            $attach.Load()


            #
            #Check for invalid characters in name
            #
            #

            Write-Debug "Download attachment dir: $($downloadDir)"
            $oFilePath = (Join-Path -Path $downloadDir -ChildPath $attach.Name.ToString())
            Write-Debug "Downloaded Attachment : $(Join-Path -Path $downloadDir -ChildPath $attach.Name.ToString())"
            # Write-Host "Attachment path: $($oFilePath)"
            $oFile = new-object System.IO.FileStream("$($oFilePath)", [System.IO.FileMode]::Create)
            $oFile.Write($attach.Content, 0, $attach.Content.Length)
            $oFile.Close()

            
        }
    }
}

Function Get-MailItems {
    Param(
        $folder,
        $itemView,
        $downloadDir
    )
    $localEmailArray = New-Object System.Collections.Generic.List[System.Object]
    $tempDownloadDir = Join-Path -Path $downloadDir -ChildPath $folder.DisplayName
    # Write-Host "Getting mail for $($folder.DisplayName)"
    $fiItems = $service.FindItems($folder.Id, $itemView) 
    for ($i = 0; $i -le $fiItems.Items.count - 1; $i++) {
        $Item = $fiItems.Items[$i]
        # write-host $fiItems.Items.count, $i, $Item.Subject
        $emailItem = "" | Select Label, Sender, Subject, Recipients, ReceivedDate, Id, TextBody, Size, DateTimeSent, DateTimeCreated
        # Write-Host "Processing $($Item.Subject)"
        $Item.Load($PropertySet)
        $emailItem.TextBody = $Item.Body.toString()
        # $bodyText = $Item.Body.toString()
        # if($bodyText){
        #     $tempBody = $bodyText -split "From:" | Select -First 1
        #     $emailItem.TextBody = $tempBody -replace "`n",", " -replace "`r",", " -replace ","," "
        # }
        # else{
        #     $emailItem.TextBody = " "
        # }
       
        $emailItem.Recipients
        $emailItem.Label = $folder.DisplayName
        $emailItem.Id = $Item.Id   
        $emailItem.ReceivedDate = $Item.DateTimeReceived   
        $emailItem.Subject = $Item.Subject   
        $emailItem.Size = $Item.Size  
        $emailItem.Sender = $Item.Sender 
        $emailItem.DateTimeSent = $Item.DateTimeSent
        $emailItem.DateTimeCreated = $Item.DateTimeCreated
        $localEmailArray.Add($emailItem)
        Get-Attachments $Item $tempDownloadDir
        Write-Progress -Activity "Processing emails in $folder" -Status "Item number $i" -PercentComplete ($i / $fiItems.Items.count * 100)  
    } 
    # else { 
    #     "Error Folder Not Found"  
    #     $tfTargetFolder = $null  
    #     break
    # }
    return $localEmailArray


    # foreach ($Item in $fiItems.Items) {  
    #     $emailItem = "" | Select Label, Sender, Subject, ReceivedDate, Id, TextBody, Size, DateTimeSent, DateTimeCreated
    #     # Write-Host "Processing $($Item.Subject)" 

    #     $Item.Load($PropertySet)
    #     # $Item | Select-Object -Property * | fl
        

    # }
}

# Set config.xml path
$configFile = "C:\Users\tecmmx\Desktop\code\powershell\config.xml"
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
$File = $config.configuration.appSettings['pass'].InnerText
$dllpath = $config.configuration.appSettings['dllpath'].InnerText
$logFile = $config.configuration.appSettings['logFile'].InnerText
$outCsv = $config.configuration.appSettings['outFile'].InnerText
$FolderName = @(($config.configuration.appSettings['getFolders'].InnerText) -split ",")

$EWSServicePath = $dllpath
Import-Module $EWSServicePath

if (!$PSScriptRoot) {
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent 
}

$ExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013
$service = new-object Microsoft.Exchange.WebServices.Data.ExchangeService($ExchangeVersion)
$psCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, (Get-Content $File | ConvertTo-SecureString)
$creds = New-Object System.Net.NetworkCredential($psCred.UserName.ToString(), $psCred.GetNetworkCredential().password.ToString())    
$service.Credentials = $creds 
$PropertySet = New-Object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)
$PropertySet.RequestedBodyType = [Microsoft.Exchange.WebServices.Data.BodyType]::Text

$service.Url = new-object Uri($uri)

$ivItemView = New-Object Microsoft.Exchange.WebServices.Data.ItemView(2000)  
$folderView = New-Object Microsoft.Exchange.WebServices.Data.Folderview(100)
#Bind to the MSGFolder Root 
# $folderid = new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot, $MailboxName)
$rootFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service, [Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot)

$folders = $rootFolder.FindFolders($folderView)

foreach ($folder in $folders) {
    if ($folder.DisplayName -notin ("Calendar", "Contacts", "Conflicts", "Conversation History", "OutBox", "Recipient Cache", "vm")) {
        $returnedArray = Check-ChildFolders $folder $folderView $ivItemView $service $downloadDir
        if ($returnedArray) {
            $emailArray.AddRange($returnedArray)
        }
    }
}


$outPath = Join-Path -Path $PSScriptRoot -ChildPath $outCsv
Write-Debug "Writing $($outPath)"

$emailArray | Export-Csv (Join-Path -Path $PSScriptRoot -ChildPath $outCsv) -NoTypeInformation
# Write-Host "Done!"

# Id                       : AAMkAGVkMWZlMTQyLWYwOTItNDlkOS05YWEwLTc4ODY5NTQ4ZjkyYwAuAAAAAADRLh5VmC2wTIfPTvIiYtWvAQC3z2nxN0cETJPlbz
#                            csGHjvAAAAWJklAAA=
# ParentFolderId           : AAMkAGVkMWZlMTQyLWYwOTItNDlkOS05YWEwLTc4ODY5NTQ4ZjkyYwAuAAAAAADRLh5VmC2wTIfPTvIiYtWvAQC3z2nxN0cETJPlbz
#                            csGHjvAAAAAAEIAAA=
# ChildFolderCount         : 0
# DisplayName              : vm
# FolderClass              : IPF.Note
# TotalCount               : 9
# ExtendedProperties       : {}
# ManagedFolderInformation :
# EffectiveRights          : CreateAssociated, CreateContents, CreateHierarchy, Delete, Modify, Read, ViewPrivateItems
# Permissions              : {}
# UnreadCount              : 0
# PolicyTag                :
# ArchiveTag               :
# WellKnownFolderName      :
# Schema                   : {Id, ParentFolderId, FolderClass, DisplayName...}
# Service                  : Microsoft.Exchange.WebServices.Data.ExchangeService
# IsNew                    : False
# IsDirty                  : False
