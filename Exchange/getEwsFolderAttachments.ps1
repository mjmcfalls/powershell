# Set config.xml path
$configFile = "C:\folder\location\with\config.xml"
# Import Configuration xml file
$config = New-Object -TypeName XML
$config.Load($configFile)
# Set variables from configuration xml files
$emailArray = @()
$PathToSearch = "\" 
$uri = $config.configuration.appSettings['uri'].InnerText
$MailboxName = $config.configuration.appSettings['MailboxName'].InnerText
$user = $config.configuration.appSettings['user'].InnerText
$File = $config.configuration.appSettings['pass'].InnerText
$dllpath = $config.configuration.appSettings['dllpath'].InnerText
$logFile = $config.configuration.appSettings['logFile'].InnerText
$outCsv = $config.configuration.appSettings['outFile'].InnerText
$FolderName = @(($config.configuration.appSettings['getFolders'].InnerText) -split ",")
$downloadDirectory = "C:\Outlocation\"
$EWSServicePath = $dllpath
Import-Module $EWSServicePath

$ExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013
$service = new-object Microsoft.Exchange.WebServices.Data.ExchangeService($ExchangeVersion)
$psCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, (Get-Content $File | ConvertTo-SecureString)
$creds = New-Object System.Net.NetworkCredential($psCred.UserName.ToString(), $psCred.GetNetworkCredential().password.ToString())    
$service.Credentials = $creds 

# Email Message Property set
$PropertySet = New-Object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)
$PropertySet.RequestedBodyType = [Microsoft.Exchange.WebServices.Data.BodyType]::Text

$service.Url = new-object Uri($uri)

$ivItemView = New-Object Microsoft.Exchange.WebServices.Data.ItemView(1000)  

#Bind to the MSGFolder Root 
$folderid = new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot, $MailboxName)   
# Write-Host "FolderId: ", $folderid
foreach ($folder in $FolderName) {
    $tfTargetFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service, $folderid)
    $fvFolderView = new-object Microsoft.Exchange.WebServices.Data.FolderView(1) 
    $fvFolderView.Traversal = [Microsoft.Exchange.Webservices.Data.FolderTraversal]::Deep
    $SfSearchFilter = new-object Microsoft.Exchange.WebServices.Data.SearchFilter+IsEqualTo([Microsoft.Exchange.WebServices.Data.FolderSchema]::DisplayName, $folder) 
    $findFolderResults = $service.FindFolders($tfTargetFolder.Id, $SfSearchFilter, $fvFolderView) 
    # Write-Host "Folder Search Count: ", $findFolderResults.TotalCount
    # $findFolderResults
    if ($findFolderResults.TotalCount -eq 1) { 
        $fiItems = $service.FindItems($findFolderResults.Id, $ivItemView) 
        # $fiItems.TotalCount
        # $fiItems | export-csv RawStatusEmail.Csv -NoTypeInformation
        foreach ($Item in $fiItems.Items) {  
            
            $emailItem = "" | Select Label, Sender, Subject, ReceivedDate, Id, TextBody, Size, DateTimeSent, DateTimeCreated
            # "ReceivedDate : " + $Item.DateTimeReceived   
            # "Subject     : " + $Item.Subject   
            # "Size        : " + $Item.Size  
            Write-Host "Processing $($Item.Subject)"
            # Write-Host ($Item | select -Property *)
            $Item.Load($PropertySet)
            # $Item | Select-Object -Property * | fl
            if ($Item.hasAttachments) {
                # $Item.Attachments
                foreach ($attach in $Item.Attachments) {
                    # $attach
                    $attach.Load()
                    $oFile = new-object System.IO.FileStream((Join-Path -Path $downloadDirectory -ChildPath $attach.Name.ToString()), [System.IO.FileMode]::Create)
                    $oFile.Write($attach.Content, 0, $attach.Content.Length)
                    $oFile.Close()
                    write-host "Downloaded Attachment : $(Join-Path -Path $downloadDirectory -ChildPath $attach.Name.ToString())"
                }
            }  
        }    
    }
}
# $emailArray | format-table
# Write-Host "Writing $($outCsv)"
# $emailArray | Export-Csv $outCsv -NoTypeInformation
# Write-Host 'Done!'
