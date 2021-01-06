[CmdletBinding(
    SupportsShouldProcess = $True
)]
param(
    [String]$token,
    [String]$server = "airwatch-server.domain.tld",
    [string]$user,
    [string]$pass
)

$headers = @{ 
    "aw-tenant-code" = ""
    "Authorization"  = ""
    "Content-Type"   = "application/json"
}

$results = New-Object System.Collections.Generic.List[System.Object]

$headers["aw-tenant-code"] = $token

$pair = "$($user):$($pass)"
$bytes = [System.Text.Encoding]::ASCII.GetBytes($pair)
$base64 = [System.Convert]::ToBase64String($bytes)
$basicAuthValue = "Basic $base64"
$headers['Authorization'] = $basicAuthValue

$uri = "https://$($server)/api/mdm/smartgroups/search"
# $appsUri = "https://$($server)/api/mdm/smartgroups/ID/apps"
$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

foreach ($item in $response.SmartGroups) {
    $psobj = [PSCustomObject]@{
        SmartGroupName                 = ''
        ManagedByOrganizationGroupName = ''
        Assignments                    = ''
        Devices                        = ''
        SmartGroupID                   = ''
        apps                           = ''
    }

    # Write-Host "$($item.Name) - Devices: $($item.Devices)"
    $psobj.SmartGroupID = $item.SmartGroupID
    $psobj.SmartGroupName = $item.Name
    $psobj.Assignments = $item.Assignments
    $psobj.Devices = $item.Devices
    $psobj.ManagedByOrganizationGroupName = $item.ManagedByOrganizationGroupName
    $appsUri = "https://$($server)/api/mdm/smartgroups/$($item.SmartGroupID)/apps"

    $appsResponse = Invoke-RestMethod -Uri $appsUri -Method Get -Headers $headers

    if ($appsResponse) {
        $count = ($appsResponse | Measure-Object).Count
        # Write-Host "Number of apps: $($count)"
        foreach($app in $appsResponse){
            if($psobj.apps -eq ''){
                $psobj.apps = $app.applicationName
            }
            else{
                $psobj.apps = $psobj.apps + ",$($app.applicationName)"
            }
        }        
    }
    $results.Add($psobj)
    # $apps
}

$results