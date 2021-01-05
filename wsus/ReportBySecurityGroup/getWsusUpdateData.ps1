[CmdletBinding(
    SupportsShouldProcess = $True
)]
param(
    [string]$uri = "https://OrionServer:17778/SolarWinds/InformationService/v3/Json/Query",
    [string]$user,
    [string]$pass,
    [switch]$export,
    [string]$exportPath = "c:\Scripts\wsus\data\",
    [string]$config = "config.json",
    [string]$log = "wsus_report.log"
)

Function Get-OrionData {
    param(
        [string]$uri = "https://OrionServer:17778/SolarWinds/InformationService/v3/Json/Query",
        [string]$name,
        [string]$ipaddress,
        [string]$dnsname,
        $cred 
    )
    # Write-Host "Name: $($name)"
    # Write-Host "DNS Name: $($dnsname)"
    add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Ssl3, [Net.SecurityProtocolType]::Tls, [Net.SecurityProtocolType]::Tls11, [Net.SecurityProtocolType]::Tls12


    $results = $null

    # $data = @{"query" = "SELECT Caption, DNS, SysName,LastBoot, SystemUpTime, NodeName, DisplayName FROM Orion.Nodes WHERE NodeName='$($name)' OR NodeName='$($dnsname)'" }
    $data = @{"query" = "SELECT Caption, DNS, SysName,LastBoot, SystemUpTime, NodeName, DisplayName, IPAddress FROM Orion.Nodes WHERE IPAddress='$($ipaddress)'" }
    $jsondata = $data | ConvertTo-Json
    # Write-Host $jsondata
    Try {
        $apiresults = Invoke-RestMethod -Uri $uri -Method POST -Body $jsondata -ContentType "application/json" -Credential $cred
        # Write-Host $apiresults.results
        # Write-Host "ApiResults Length: $($apiresults.results.length)"
        if ($apiresults) {
            # Write-Host "$($apiResults.results | Get-Member)"
            # Write-Host "LastBoot: $($apiResults.results.LastBoot)"
            if ($apiresults.results.length -eq 1) {
                $results = $apiResults.results
            }
            elseif ($apiresults.results.length -gt 1) {
                foreach ($item in $apiresults.results) {
                    if ($item.DisplayName -match $name -or $item.DisplayName -match $dnsname) {
                        $results = $item
                        break
                    }
                }
            }
        }
        else {
            # "No Results found"
        }
    }
    Catch {
        # pass
    }
    $results
}
Function Get-WsusData {
    param(
        [string]$uri = "WSUSServer",
        [int]$port = 80
    )
    [void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
    $script:Wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($uri, $false, $port)
    $computerscope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
    $updatescope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
    $updatescope.ExcludedInstallationStates = 'NotApplicable', 'Unknown', 'Installed'

    # Write-Host "Getting Computers"
    $computers = New-Object System.Collections.Generic.List[System.Object]
    $wsus.GetComputerTargets() | Where-Object { $_.RequestedTargetGroupName -eq "Windows_Security_Group" } | ForEach-Object {
        # $_ 
        $psobj = [PSCustomObject]@{
            Id                          = $_.Id
            Name                        = $wsus.GetComputerTarget(($_.Id)).FullDomainName.split(".")[0]
            DNS                         = $wsus.GetComputerTarget(($_.Id)).FullDomainName
            IP                          = $_.IPAddress
            LastBoot                    = $null
            # LastSyncTime = $_.LastSyncTime
            # LastSyncResult = $_.LastSyncResult
            # LastReportedStatusTime = $_.LastReportedStatusTime
            # LastReportedInventoryTime = $_.LastReportedInventoryTime
            # RequestedTargetGroupName = $_.RequestedTargetGroupName
            OSDescription               = $_.OSDescription
            UnknownCount                = $null
            NotApplicableCount          = $null
            NotInstalledCount           = $null
            DownloadedCount             = $null
            InstalledCount              = $null
            InstalledPendingRebootCount = $null
            FailedCount                 = $null
        }
        # $psobj
        $computers.add($psobj)
    }

    $summaries = $wsus.GetSummariesPerComputerTarget($updatescope, $computerscope) | Where-Object { $computers.Id -contains $_.ComputerTargetId } 
    Foreach ($s in $summaries) {
        Foreach ($c in $computers) {
            If ( $s.ComputerTargetId -eq $c.Id ) {
                $c.UnknownCount = $s.UnknownCount
                $c.NotApplicableCount = $s.NotApplicableCount
                $c.NotInstalledCount = $s.NotInstalledCount
                $c.DownloadedCount = $s.DownloadedCount
                $c.InstalledCount = $s.InstalledCount
                $c.InstalledPendingRebootCount = $s.InstalledPendingRebootCount
                $c.FailedCount = $s.FailedCount
            }
        }
    }
    $computers
}

Function Send-report {
    param(
        $config,
        $file,
        $fdate = $(Get-Date),
        $log

    )

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
    $params = Get-Content $config -Raw | ConvertFrom-Json
   
    foreach ($param in $params.PSObject.Properties) {
        if ($msgparams.ContainsKey($param.Name.toLower())) {
            if ($param.Name.toLower() -eq "version") {
                # Do nothing with version.  This is for tracking the config version number.
            }
            else {
                if ($param.Name.toLower() -eq "to") {
                    foreach ($email in $param.Value) {
                        $to = $to + $email.email
                    }
                    $msgparams.($param.Name.toLower()) = $to
                    Write-Log -Level "INFO" -Message "Setting To Field to: $($msgparams.to)" -logfile $log
                }
                elseif ($param.Name.toLower() -eq "cc") {
                    foreach ($email in $param.Value) {
                        $cc = $cc + $email.email
                    }
                    $msgparams.($param.Name.toLower()) = $cc
                    Write-Log -Level "INFO" -Message "Setting CC Field to: $($msgparams.cc)" -logfile $log
                }
                else {
                    $msgparams.($param.Name.toLower()) = $param.Value 
                } 
            }  
        }
    }
    
    $msgparams.body = (($params.body -Replace "DATE", "$($fdate)") -Replace "SAVED", "$($file)") -Replace "SERVER","$($env:computername)"
    Write-Log -Level "INFO" -Message "Setting email Body to: $($msgparams.body)" -logfile $log

    $msgparams.attachments = "$($file)"
    Write-Log -Level "INFO" -Message "Setting email attachment: $($msgparams.attachments)" -logfile $log

    $msgparams.subject = $params.subject -Replace "DATE", "$($fdate)"
    Write-Log -Level "INFO" -Message "Setting email subject to: $($msgparams.subject)" -logfile $log

    Write-Log -Level "INFO" -Message "Sending email." -logfile $log
    # $msgparams.body
    $results = send-mailmessage @msgparams 
    # $reults
    Write-Log -Level "INFO" -Message "Email results: $($results)" -logfile $log
}
Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
        [String]
        $Level = "INFO",
        [Parameter(Mandatory = $True)]
        [string]
        $Message,
        [Parameter(Mandatory = $False)]
        [string]
        $logfile
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    If ($logfile) {
        Add-Content $logfile -Value $Line
    }
    Else {
        Write-Output $Line
    }
}

Function Invoke-Main {
    param(
        [string]$wsusUri = "MHSServerWSUS",
        [int]$wsusPort = 80,
        [string]$uri = "https://OrionServer:17778/SolarWinds/InformationService/v3/Json/Query",
        [string]$user,
        [string]$pass,
        [switch]$export,
        [string]$exportPath,
        [string]$config,
        [string]$log
    )
    

    $header = @{ }
    $Params = @{ }

    $date = $(get-date)
    $filedate = $date.tostring('yyyyMMdd_HHmmss')
    $file = Join-Path -Path $exportPath -ChildPath "WSUS_Report_$($filedate).csv"

    Write-Log -Level "INFO" -Message "Setting Export file to: $($file)" -logfile $log

    # Get api secure password
    $fcontents = Get-Content -Path $pass
    $securestring = ConvertTo-SecureString $fcontents
    $cred = New-Object System.Management.Automation.PSCredential("apisvc", $securestring)
    Write-Log -Level "INFO" -Message "Pulling Wsus data from $($wsusUri):$($wsusPort)"
    $computers = Get-WsusData -uri $wsusUri -port $wsusPort
    
    Write-Log -Level "INFO" -Message "Pulling last boot data from Orion by server name" -logfile $log
    $computers | ForEach-Object { 
        $_.PSObject.Members.Remove("Id")
        $results = Get-OrionData -name $_.Name -dnsname $_.DNS -ipaddress $_.IP  -cred $cred
        if ($results) {
            # $_.LastBoot = ([datetime]$results.LastBoot).AddHours(-6)
            $_.LastBoot = ([datetime]$results.LastBoot)
        }
        
    }

    if ($export) {
        Write-Log -Level "INFO" -Message "Export Flag set - Exporting data to $($file)" -logfile $log
        $computers | Export-Csv -Path "$($file)" -NoTypeInformation
        Write-Log -Level "INFO" -Message "Starting Email configuration" -logfile $log
        Send-report -config $config -file $file -fdate $date -log $log
    }
    else {
        $computers
    }
}

# Build Hashtable for splatting main function
$params = @{
    uri = $uri
    user = $user
    pass = $pass
    export = $export
    exportPath = $exportPath
    config = $config
    log = $log
 }
Foreach ($key in $PSBoundParameters.Keys) {
    if($params.ContainsKey($key)){
        $params.$key = $PSBoundParameters.$key
    }
    else{
        $params.Add($key, $PSBoundParameters.$key)
    }
    
}

Invoke-main @params
# Invoke-main -user $user -pass $pass -export -exportPath $exportPath -config $config

