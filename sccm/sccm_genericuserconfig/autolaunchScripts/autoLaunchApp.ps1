[CmdletBinding(
    SupportsShouldProcess = $True
)]
param(
    [string]$app,
    [string]$uri = $null,
    [string]$configFile = "c:\admin\config.json"
)

$inputParams = @{
    app = $app;
    uri = $uri;
    httpRegex = "(page1)|(pag2)|(page3)|(page4)|(page5)";
    configFile = $configFile;
}

Function Start-App {
    [CmdletBinding(SupportsShouldProcess = $True)]
    param(
        [string]$app,
        [string]$uri = $null,
        [string]$configFile
    )

    Write-Host "$((Get-Date).toString("yyyy/MM/dd HH:mm:ss")) - Attempting to start $($app)"
    if ($app) {
        if ($app.ToLower() -match "firstnet") {
            C:\"Program Files (x86)"\Citrix\"ICA Client"\SelfServicePlugin\selfservice.exe -qlaunch "Firstnet tracking board prod - p230"
        }
        elseif ($app.ToLower() -match "surginet") {
            C:\"Program Files (x86)"\Citrix\"ICA Client"\SelfServicePlugin\SelfService.exe -qlaunch "Surginet tracking board prod - p230"
        }
        elseif ($app.ToLower() -match "spm") {
            C:\"Program Files (x86)"\Microsystems\SPM\SPM.Client.UI.Wpf.exe /needslist
        }
        elseif ($app.ToLower() -eq "http") {
            if ($uri) {
                Write-Host "Starting http - URI: $($uri)"
                C:\"Program Files (x86)"\Google\Chrome\Application\chrome.exe --kiosk $uri
            }
            else {
                Throw "NoUriProvided"
            }
        }
        else{
            Throw "NoAppFound"
        }
    }
}

Function Get-ProcessCount {
    [CmdletBinding(
    SupportsShouldProcess = $True
)]
    param(
        [string]$app,
        [string]$httpRegex
    )
    if ($app.ToLower() -eq "firstnet" -or $app.ToLower() -eq "surginet") {
        # $processes = get-process | Where-Object { $_.ProcessName.StartsWith("wfica32") -and $_.MainWindowTitle -match "$($app)" }
        $processes = get-process | Where-Object { $_.ProcessName.StartsWith("wfica32") }
    }
    elseif ($app.ToLower() -eq "spm") {
        $processes = get-process | Where-Object { $_.ProcessName.StartsWith("SPM.Client.UI.Wpf") }
    }
    # elseif($app.ToLower() -eq "edcensus"){
    #     $processes = get-process | Where-Object { $_.ProcessName -eq "chrome" -and $_.MainWindowTitle -match "QlikView" }
    # }
    elseif ($app.ToLower() -eq "http") {
        $processes = get-process | Where-Object { $_.ProcessName.ToLower() -eq "chrome" -and $_.MainWindowTitle -imatch $httpRegex }
    }
    # Write-Host "Processes $($processes)"
    $processes
}

Function Invoke-Main {
    [CmdletBinding(SupportsShouldProcess = $True)]
    param(
        [string]$app,
        [string]$uri = $null,
        [string]$httpRegex,
        [string]$configFile
    )
    Write-Host "App: $($app)"
    $mainParams = @{
        app         = $app;
        uri         = $uri;
    }
    if(Test-Path $configFile){
        Write-Host "Config file exists"
        $configContent = Get-Content $configFile | ConvertFrom-Json
        if ($configContent.firstrun.firstrun -eq $false){
            Write-Host "Starting first run configuration - $($configContent.firstrun.url)"
            C:\"Program Files (x86)"\Google\Chrome\Application\chrome.exe $configContent.firstrun.url 

            Write-Host "Saving First run config."
            $configContent.firstrun.firstrun = $true
            $configContent | ConvertTo-Json | Set-Content $configFile
            Start-Sleep -Seconds 5
            exit 0
        }
    }
    else{
        Write-Host "No Config file found!"
    }

    $processes = Get-ProcessCount -app $app -httpRegex $httpRegex

    if ($processes) {
        Write-Host "$((Get-Date).toString("yyyy/MM/dd HH:mm:ss")) - $($processes.Count) running $($app) found!"
        if ($processes.Count -eq 0) { 
            # Logic to handle no open apps
            Start-App @mainParams
        }
        elseif ($processes.Count -gt 1) {
            # Logic to handle multiple open apps
            $processes | Stop-Process -Force
            Start-App @mainParams
        }
        elseif($processes.Count -eq 1){
            # Pass
        }
    }
    else {
        # Open app if processes is empty
        Write-Host "$((Get-Date).toString("yyyy/MM/dd HH:mm:ss")) - No processes found for $($app)!"
        Start-App @mainParams
    }
}

Invoke-Main @inputParams
