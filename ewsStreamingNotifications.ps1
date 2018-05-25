$configFile = "$($PSScriptRoot)\config.xml"
$config = [xml](get-content $configFile)
$uri = $config.configuration.appSettings['uri']
$MailboxName = $config.configuration.appSettings['MailboxName']
$user = $config.configuration.appSettings['user']
$File = $config.configuration.appSettings['pass']
$dllpath = $config.configuration.appSettings['dllpath']
$logFile = $config.configuration.appSettings['logFile']

$EWSServicePath = $dllpath
Import-Module $EWSServicePath

# Create Log file if it does not exists
if(-Not (test-path "$($PSScriptRoot)\logs\$($logFile)")){
    New-Item "$($PSScriptRoot)\logs\$($logFile)" -ItemType File > $null
    "Date;Id;Label;mlActioned;Sender;Subject;Body" | Out-File "$($PSScriptRoot)\logs\ewsNotification.log" -Encoding UTF8 -Append
}

[void][Reflection.Assembly]::LoadFile($dllpath)  
$service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService([Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2013)  
$service.TraceEnabled = $false  
$psCred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $user, (Get-Content $File | ConvertTo-SecureString)
$creds = New-Object System.Net.NetworkCredential($psCred.UserName.ToString(),$psCred.GetNetworkCredential().password.ToString())    
$service.Credentials = $creds 
# $service.Credentials = New-Object System.Net.NetworkCredential("user@domain.com","password")  
# $service.AutodiscoverUrl($MailboxName ,{$true})  
$service.Url = new-object Uri($uri)
$fldArray = new-object Microsoft.Exchange.WebServices.Data.FolderId[] 1  
$Inboxid = new-object Microsoft.Exchange.WebServices.Data.FolderId([Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Inbox,$MailboxName)  
$fldArray[0] = $Inboxid  
$stmsubscription = $service.SubscribeToStreamingNotifications($fldArray, [Microsoft.Exchange.WebServices.Data.EventType]::NewMail)  
$stmConnection = new-object Microsoft.Exchange.WebServices.Data.StreamingSubscriptionConnection($service, 30);  
$stmConnection.AddSubscription($stmsubscription)  

Register-ObjectEvent -inputObject $stmConnection -eventName "OnNotificationEvent" -Action { 
    $PropertySet = New-Object Microsoft.Exchange.WebServices.Data.PropertySet([Microsoft.Exchange.WebServices.Data.BasePropertySet]::FirstClassProperties)
    $PropertySet.RequestedBodyType = [Microsoft.Exchange.WebServices.Data.BodyType]::Text 

    foreach($notEvent in $event.SourceEventArgs.Events){      
        [String]$itmId = $notEvent.ItemId.UniqueId.ToString()  
        $message = [Microsoft.Exchange.WebServices.Data.EmailMessage]::Bind($event.MessageData,$itmId) 
        $message.Load($PropertySet) 
        $bodyText = $message.Body.toString()
        if($bodyText){
            $tempBody = $bodyText -split "From:" | Select -First 1
            $bodyText  = $tempBody -replace "`n",", " -replace "`r",", " -replace ","," "
        }
        else{
            $bodyText = " "
        }
        # "Date;Id;Label;mlActioned;Sender;Subject;Body"
        "$(Get-Date);$($message.Id);;0;$($message.Sender);$($message.Subject);$($bodyText)" | Out-File "$($PSScriptRoot)\logs\ewsNotification.log" -Encoding UTF8 -Append
    }   
} -MessageData $service  
Register-ObjectEvent -inputObject $stmConnection -eventName "OnDisconnect" -Action {$event.MessageData.Open()} -MessageData $stmConnection  
$stmConnection.Open() 
