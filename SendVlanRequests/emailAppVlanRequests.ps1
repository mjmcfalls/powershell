
$msgparams = @{
    smtp = $null;
    port= $null;
    subject = $null;
    to = $null;
    # cc = $null;
    from = $null;
    # attachments = $null;
    body = $null;
}

$to = @()
$cc = @()
$config = "config.json"
$dir = "src_data\"
$date = $(get-date)
$file = "\\server\share\app_vlan_requests.csv"

$Header = @"
<style>
TABLE {border-width: 0px; border-style: solid; border-color: black; border-collapse: collapse;}
TD {border-width: 1px; padding: 5px; border-style: solid; border-color: black;}
</style>
"@

# Build msgparams
$params = Get-Content $config | ConvertFrom-Json

foreach($param in $params.PSObject.Properties){
    if($msgparams.ContainsKey($param.Name.toLower())){
        if($param.Name.toLower() -eq "version"){
            # Do nothing with version.  This is for tracking the config version number.
        }
        else{
            if ($param.Name.toLower() -eq "to"){
                foreach($email in $param.Value){
                    $to = $to + $email.email
                }
                $msgparams.($param.Name.toLower()) = $to
            }
            elseif($param.Name.toLower() -eq "cc"){
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

$xls = Import-CSV $file  | Where-Object { ($_.PSObject.Properties | ForEach-Object {$_.Value}) -ne $null}
# $xls
$count = 0
$requested = New-Object System.Collections.Generic.List[System.Object]
foreach ($row in $xls){
    if ($row.Requested -eq "" -or ($row.Requested).toLower() -eq $false){
        # $row
        $count += 1
    }
}

Write-host "Vlans to process: $($count)"
# ($xls | Where {$_.Requested -eq $null -or $_.Requested -eq $false }).count
if ($count -gt 0){
    foreach ($row in $xls){
        if($row.Requested -eq "" -or ($row.Requested).toLower() -eq $false){
            $row
            $row.Requested = $true
            $row.requestDate = $date.ToString("MM-dd-yyyy")

            $copy = $row.PsObject.Copy()
            $copy.PSObject.Properties.Remove('Requested')
            $copy.PSObject.Properties.Remove('IP')

            $requested.add($copy)
        }
    }

    $body = "Application VLAN Requests for $($date.ToString("yyyy-MM-dd"))<br/><br/>$($requested | ConvertTo-Html -Head $header | Out-String)<br/><br/>This email is auto-generated for any new Application VLAN requests."
    $msgparams.body = $body
    $msgparams.subject = "Application VLAN Requests - $($date.ToString("yyyy-MM-dd"))"
    $msgparams
    # $msgparams.body | out-File Test.html
    $results = send-mailmessage @msgparams -BodyAsHtml
    $xls | Export-CSV -Path $file -NoTypeInformation
}
else{
    "No Vlans to process"
}

