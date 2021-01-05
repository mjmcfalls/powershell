[CmdletBinding()]
param(
    [string]$file = "email",
    [string]$downloadDir
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
    # Write-Host "Check-ChildFolders Folder: $($folder.DisplayName)"
    $folderEmailArray = New-Object System.Collections.Generic.List[System.Object]
    
    # if ($folder.ChildFolderCount -gt 0) {
    $cFolders = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service, $folder.Id)
    $folds = $cFolders.FindFolders($folderView)
    foreach ($fold in $folds) {
        # if ($fold.TotalCount -gt 0) {
        # Write-Host "$($fold.DisplayName); Msg Count: $($fold.TotalCount); Child Folders: $($fold.ChildFolderCount)"
        # Write-Host "FolderEmailArray Count: $($folderEmailArray.count)"
        # if ($fold.ChildFoldercount -gt 0) {
        # Write-Host $cFolder.DisplayName
        $returnedFoldArray = Check-ChildFolders $fold $folderview $itemView $service $downloadDir
        # }
        # else {
        #     $returnedFoldArray = Get-MailItems $fold $ivItemView $downloadDir
        # }

        if ($returnedFoldArray) {
            $folderEmailArray.AddRange($returnedFoldArray)
        }
        # }
    }
    # }

    # Get root folder email
    # Write-Host ($folder | Select-Object -Property * | Format-List | Out-String)
    # if ($folder.TotalCount -gt 0) {
    # Write-Host ($folder | Select-Object -Property * | Format-List | Out-String)
    # Write-Host "Get email for: $($folder.DisplayName)"
    $returnRootEmailArray = Get-MailItems $folder $ivItemView $downloadDir
    
    if ($returnRootEmailArray) {
        $folderEmailArray.AddRange($returnRootEmailArray)
    }
        
    # }
   
    return $folderEmailArray
}

Function Get-Attachments {
    Param(
        $item,
        $downloadDir 
    )

    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars() -join ''

    $invalidCharsRegex = "[" + [regex]::Escape($invalidChars) + "]"
    $epochStart = Get-Date -Date "01/01/1970"
    if ($item.hasAttachments) {
        if (-Not (Test-Path $downloadDir -PathType Container)) {
            New-Item -ItemType Directory -Force -Path $downloadDir #| Out-Null
        }

        foreach ($attach in $Item.Attachments) {
            $attach.Load()
            # Write-Host ($attach | Select-Object -Property * | Format-List | Out-String)
            $FileEpochTime = (New-Timespan -Start $epochStart -end $attach.LastModifiedTime).TotalSeconds
            if ($attach.Content.Length -gt 0) {
                $attachName = ($attach.Name.ToString().trim())
                $attachName = "$($attach.id[-7..-1] -join '')$($FileEpochTime)_" + $attachName
                Write-Host "Downloading: $($attachName); Size: $($attach.Content.Length)"
                if ($attachName -match $invalidCharsRegex) {
                    Write-Debug "$($attachName) contains invalid characters"
                    $attachName = $attachName.split([System.IO.Path]::GetInvalidFileNameChars()) -join ""
                    Write-Debug "$($attachName) after character removal"
                } 
    
                # Write-Debug "Download attachment dir: $($downloadDir)"
                $oFilePath = (Join-Path -Path $downloadDir -ChildPath $attachName)
                Write-Debug "Downloaded Attachment : $($oFilePath)"
                # # Write-Host "Attachment path: $($oFilePath)"
                $oFile = new-object System.IO.FileStream("$($oFilePath)", [System.IO.FileMode]::Create)
                $oFile.Write($attach.Content, 0, $attach.Content.Length)
                $oFile.Close()
            }
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
    Write-Host "Getting mail for $($folder.DisplayName)"
    $fiItems = $service.FindItems($folder.Id, $itemView)

    for ($i = 0; $i -le $fiItems.Items.count - 1; $i++) {
        $Item = $fiItems.Items[$i]
        # Write-Host ($Item | Get-Member)
        
        $emailProperties = @{ }
        # Write-Host "Processing $($Item.Subject)"
        $Item.Load($PropertySet)
        if ($Item.Body) { 
            # $tempBody = $bodyText -split "From:" | Select -First 1
            # $emailProperties.Add("TextBody", ($Item.Body.ToString() -replace '`"', '' -replace '`r`n', ''))
            $emailProperties.Add("Body", ("`'" + $Item.Body.ToString() + "`'"))
            # -replace "`n",' ' -replace "`r",' ' 
        }
        else {
            $emailProperties.Add("TextBody", $null)
        }
        $ToRecipients = $Item.ToRecipients -join ";" -Replace "SMTP:", ""
        $ccRecipients = $Item.CcRecipients -join ";" -Replace "SMTP:", ""
        # Write-Host "$($ToRecipients)"
        # Write-Host "DateTime String: $($Item.DateTimeReceived.ToString())"
        # Write-Host "DateTime Seconds: $($Item.DatetimeReceived.GetType())"
        $emailProperties.Add("ToRecipients", $ToRecipients.ToString())
        $emailProperties.Add("CcRecipients", $ccRecipients.ToString())
        $emailProperties.Add("Label", $folder.DisplayName)
        $emailProperties.Add("Id", $Item.Id)
        $emailProperties.Add("Subject", $Item.Subject) 
        $emailProperties.Add("Size", $Item.Size)
        $emailProperties.Add("Sender", $Item.Sender)
        $emailProperties.Add("HasAttachments", $Item.hasAttachments)
        if ($item.hasAttachments) {
            $Attachments = @()
            ForEach ($Attachment in $Item.Attachments) {
                # $Attachment.Load()
                if ($Attachment.Content.Length -gt 0) {
                    $attachName = $Attachment.Name.ToString()
                    $Attachments += $attachName
                    # Write-Host $Attachments
                    # Write-Host $attachName
                }
            }
            # Write-Host ($Attachments -join ";")
            $EmailProperties.Add("Attachments", ($Attachments -join ";"))
        }
        $emailProperties.Add("ReceivedDate", $Item.DateTimeReceived.ToString())
        $emailProperties.Add("DateTimeSent", $Item.DateTimeSent.ToString())
        $emailProperties.Add("DateTimeCreated", $Item.DateTimeCreated.ToString())
        $emailObject = New-Object -TypeName PSObject -Property $emailProperties
        $localEmailArray.Add($emailObject)
        
        Get-Attachments $Item $tempDownloadDir
        Write-Progress -Activity "Processing emails in $($folder.DisplayName)" -Status "Item number $($i)" -PercentComplete ($i / $fiItems.Items.count * 100)  
    } 
    Write-Progress -Activity "Processing emails in $($folder.DisplayName)" -Status "Ready" -Completed
    return $localEmailArray
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
        $returnedArray = Check-ChildFolders $folder $folderView $ivItemView $service $downloadDir
        if ($returnedArray) {
            $emailArray.AddRange($returnedArray)
        }
    }
}


$outPath = Join-Path -Path $downloadDir -ChildPath ($file + ".json")
Write-Debug "Writing $($outPath)"

# $emailArray | ConvertTo-Json  -Compress | Out-File ( $outPath -replace ".csv", ".json")
$emailArray | ConvertTo-Json | Out-File ( $outPath )
Write-Host "Number of Emails exported: $($emailArray.count)"