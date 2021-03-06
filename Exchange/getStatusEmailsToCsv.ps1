# Set config.xml path
$configFile = "C:\folder\with\config.xml"
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
$FolderName = @(($config.configuration.appSettings['getFolders'].InnerText) -split ",")
$outCsv = $config.configuration.appSettings['outStatusFile'].InnerText

$EWSServicePath = $dllpath
Import-Module $EWSServicePath

$ExchangeVersion = [Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013
$service = new-object Microsoft.Exchange.WebServices.Data.ExchangeService($ExchangeVersion)
$psCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, (Get-Content $File | ConvertTo-SecureString)
$creds = New-Object System.Net.NetworkCredential($psCred.UserName.ToString(),$psCred.GetNetworkCredential().password.ToString())    
$service.Credentials = $creds 

# Email Message Property set
$PropertySet = New-Object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)
$PropertySet.RequestedBodyType = [Microsoft.Exchange.WebServices.Data.BodyType]::Text

$service.Url = new-object Uri($uri)


$ivItemView =  New-Object Microsoft.Exchange.WebServices.Data.ItemView(1000)  
 
#Bind to the MSGFolder Root 
$folderid = new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::MsgFolderRoot,$MailboxName)   
# Write-Host "FolderId: ", $folderid
foreach ($folder in $FolderName){
    $tfTargetFolder = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($service,$folderid)
    $fvFolderView = new-object Microsoft.Exchange.WebServices.Data.FolderView(1) 
    $fvFolderView.Traversal = [Microsoft.Exchange.Webservices.Data.FolderTraversal]::Deep
    $SfSearchFilter = new-object Microsoft.Exchange.WebServices.Data.SearchFilter+IsEqualTo([Microsoft.Exchange.WebServices.Data.FolderSchema]::DisplayName,$folder) 
    $findFolderResults = $service.FindFolders($tfTargetFolder.Id,$SfSearchFilter,$fvFolderView) 

    if ($findFolderResults.TotalCount -eq 1){ 
        $fiItems = $service.FindItems($findFolderResults.Id,$ivItemView) 
        # foreach($Item in $fiItems.Items){  
        for($i = 0; $i -lt $fiItems.Items.count; $i++){
            $Item = $fiItems.Items[$i]
            write-host $fiItems.Items.count, $i, $Item.Subject
            $emailItem = "" | Select Label, Sender, Subject, ReceivedDate, Id, TextBody, Size, DateTimeSent, DateTimeCreated
            # Write-Host "Processing $($Item.Subject)"
            $Item.Load($PropertySet)
            $bodyText = $Item.Body.toString()
            if($bodyText){
                $tempBody = $bodyText -split "From:" | Select -First 1
                $emailItem.TextBody = $tempBody -replace "`n",", " -replace "`r",", " -replace ","," "
            }
            else{
                $emailItem.TextBody = " "
            }
           
            $emailItem.Label = $folder
            $emailItem.Id = $Item.Id   
            $emailItem.ReceivedDate = $Item.DateTimeReceived   
            $emailItem.Subject = $Item.Subject   
            $emailItem.Size = $Item.Size  
            $emailItem.Sender = $Item.Sender 
            $emailItem.DateTimeSent = $Item.DateTimeSent
            $emailItem.DateTimeCreated = $Item.DateTimeCreated
            $emailArray += $emailItem
            Write-Progress -Activity "Processing emails in $folder" -Status "Item number $i" -PercentComplete ($i/$fiItems.Items.count*100)
        }  
    } 
    else{ 
        "Error Folder Not Found"  
        $tfTargetFolder = $null  
        break  
    }     
}
# $emailArray | format-table
Write-Host "Writing $($outCsv)"
$emailArray | Export-Csv $outCsv -NoTypeInformation
Write-Host "Done!"
