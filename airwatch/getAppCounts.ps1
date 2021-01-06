[CmdletBinding(
    SupportsShouldProcess = $True
)]
param(
    [String]$token,
    [String]$server = "airwatch-server.domain.tld",
    [string]$user,
    [string]$pass
)

Function Get-TotalCount { 
    Param(
        [string]$uri
    )
    # $uri
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        # $response
        $total = $response.Total
        Write-Host "Total Devices: $($response.Total)"
    }
    catch {
        # Dig into the exception to get the Response details.
        # Note that value__ is not a typo.
        # Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
        # Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
    }
    # Write-Host "Total: $($total)"
    # if($total -eq 0){
    #     $total = $false
    # }
    $total 
}
Function Get-LicensedCount {
    Param(
        [string]$uri
    )
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
        # $response
        $total = $response.Licenses.TotalLicenses
        Write-Host "Total Devices: $($response.Total)"
    }
    catch {
        # Dig into the exception to get the Response details.
        # Note that value__ is not a typo.
        # Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
        # Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        $total = 0
    }
    $total
}
Function Get-Devicecount {
    Param(
        [string]$apptype,
        [string]$appId,
        [string]$server
    )
    $total = "0"
    # $appId
    if ($apptype -match "Internal") {
        $uri = "https://$($server)/api/mam/apps/internal/$($appId)/devices"
        $total = Get-TotalCount -uri $uri
    }
    elseif ($apptype -match "Public") {
        $uri = "https://$($server)/api/mam/apps/public/$($appId)/devices"
        $total = Get-TotalCount -uri $uri
    }
    elseif ($apptype -match "Purchased") {
        $uri = "https://$($server)/api/mam/purchased/$($appId)/devices"
        $total = Get-TotalCount -uri $uri
    }
    elseif ($apptype -match "VPP") {
        $uri = "https://$($server)/api/mam/apps/purchased/$($appId)"
        try {
            $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers
            $response
            $total = $response.Licenses.TotalLicenses
            Write-Host "Total Devices: $($response.Total)"
        }
        catch {
            # Dig into the exception to get the Response details.
            # Note that value__ is not a typo.
            # Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
            # Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
            $total = 0
        }
    }
    $total
}

# Get-VPPDevice
$platform = @{
    1   = "WindowsMobile"
    2   = "Apple"
    3   = "BlackBerry"
    4   = "Symbian"
    5   = "Android"
    8   = "WindowsPhone"
    9   = "WindowsPc"
    10  = "AppleOsX"
    11  = "WindowsPhone8"
    12  = "WinRT"
    13  = "BlackBerry10"
    14  = "Apple TV"
    16  = "ChromeBook"
    17  = "Tizen"
    101 = "ZebraPrinter"
    102 = "ToshibaPrinter"
    103 = "AveryDennisonPrinter"
    104 = "DataMaxONeilPrinter"
}

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

$uri = "https://$($server)/api/mam/apps/search?type=app"
$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

foreach ($item in $response.application) {
    $psobj = [PSCustomObject]@{
        ApplicationName = ''
        AppVersion      = ''
        DeviceCount     = ''
        AppType         = ''
        Platform        = ''
        Id              = ''
        status          = ''
        Purchased       = ''
        ApplicationUrl  = ''
    }
    foreach ($name in $psobj.PSObject.Properties) {
        # [0].Model[0].ApplicationId 
        if ($name.Name -eq "Platform") {
            $psobj.($name.Name) = $platform.($item.($name.Name))
        }
        elseif ($name.Name -eq "Id") {
            $psobj.($name.Name) = $item.($name.Name).Value
            # Write-Host "ID: $($item.($name.Name).Value)"
        }
        else {
            $psobj.($name.Name) = $item.($name.Name)  
        }
    }
    # Write-Host "$($psobj.ApplicationName) - $($psobj.Id)"
    $psobj.DeviceCount = Get-Devicecount -apptype $psobj.AppType -appId $psobj.Id
    # $psobj
    $results.Add($psobj)
}

$uri = "http://$($server)/api/mam/apps/purchased/search"
$response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers

foreach ($item in $response.application) {
    $psobj = [PSCustomObject]@{
        ApplicationName = ''
        AppVersion      = ''
        DeviceCount     = ''
        AppType         = ''
        Platform        = ''
        Id              = ''
        status          = ''
        Purchased       = ''
        ApplicationUrl  = ''
    }

    $psobj.ApplicationName = $item.ApplicationName
    $psobj.Purchased = $item.ManagedDistribution.Purchased
    $psobj.Apptype = "VPP"

    
    if ($item.Assignments.length -gt 1){
        $psobj.status = $item.Assignments[0].Status
    }
    elseif ($item.Assignments.length -eq 1){
        $psobj.status = $item.Assignments[0].Status
    }
    else{
        $psobj.status = $item.Assignments.Status
    }
    # Write-Host "$($psobj.ApplicationName) -$($item.Assignments.length) -  $(($item.Assignments.Status))"
    $psobj.Platform = $platform[$item.Platform]
    $psobj.Id = $item.Id.Value
    $psobj.ApplicationUrl = $item.ApplicationUrl

    # $psobj
    $results.Add($psobj)
}

$results