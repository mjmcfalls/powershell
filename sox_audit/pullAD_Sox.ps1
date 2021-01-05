

$msgparams = @{
    smtp = $null;
    port= $null;
    subject = $null;
    to = $null;
    cc = $null;
    from = $null;
    attachments = $null;
    body = $null;
}

$to = @()
$cc = @()
$config = "config.json"
$dir = "c:\Scripts\Sox\src_data\"
$date = $(get-date)
$filedate = $date.tostring('yyyyMMdd_HHmmss')
$file = "Sox_Audit_$($filedate).csv"
$scriptName = $MyInvocation.MyCommand.Name
$compressed =  "$($dir)Sox_Audit_$($filedate).zip"

# $compress = @{
#     Path= "$($scriptName)", "$($dir)$($file)"
#     CompressionLevel = "Fastest"
#     DestinationPath = $compressed
#     }
 
if (-Not (Test-Path -Path $dir)){
    $newdir = New-Item -ItemType Directory $dir
    Write-Host "Creating $($dir)"
}

# Fetch Active Directory user data
Get-AdUser -Filter * -Properties SamAccountName, DisplayName, GivenName, Surname, EmployeeID, Company, Department, Created, Enabled, LastLogonDate, PasswordExpired, PasswordLastSet, Title, Modified | Select-Object -Property SamAccountName, DisplayName, GivenName, Surname, EmployeeID, Company, Department, Created, Enabled, LastLogonDate, PasswordExpired, PasswordLastSet, Title, Modified | Export-CSV "$($dir)$($file)" -NoTypeInformation

Write-Host "Compressing Script and data"
# Compress-Archive @compress
$7zipPath = "$env:ProgramFiles\7-Zip\7z.exe"

if (-not (Test-Path -Path $7zipPath -PathType Leaf)) {
    throw "7 zip file $($7zipPath) not found"
}

Set-Alias 7zip $7zipPath 

7zip a -mx=9 "$($compressed)" "$($scriptName)"
Push-Location -Path $dir
7zip a -mx=9 "$($compressed)" "$($file)"
Pop-Location

# Build msgparams
$params = Get-Content $config -Raw| ConvertFrom-Json

foreach($param in $params.PSObject.Properties){
    if($msgparams.ContainsKey($param.Name.toLower())){
        if($param.Name.toLower() -eq "version"){
            # Do nothing with version.  This is for tracking the config version number.
        }
        else{
            if ($param.Name.toLower() -eq "to"){
                # Write-Host "Matches to - $($param.Name)"
                foreach($email in $param.Value){
                    $to = $to + $email.email
                }
                $msgparams.($param.Name.toLower()) = $to
            }
            elseif($param.Name.toLower() -eq "cc"){
                # Write-Host "Matches to - $($param.Name)"
                foreach($email in $param.Value){
                    $cc = $cc + $email.email
                }
                $msgparams.($param.Name.toLower()) = $cc
            }
            else{
                $msgparams.($param.Name.toLower()) = $param.Value 
            } 
        }  
    }
}

$body = "Mission Health Sox report`nRetrieved $($date)`n`nPlease do not reply to $($msgparams.from)! It is a non-existent email!"
$msgparams.body = $body
$msgparams.attachments = "$($compressed)"
$msgparams.subject = "Mission Health Sox data - $($date)"
Write-Host "Sending Email"
# $msgparams
$results = send-mailmessage @msgparams 
Write-Host $results
Remove-item "$($compressed)"
Remove-Item "$($dir)$($file)"