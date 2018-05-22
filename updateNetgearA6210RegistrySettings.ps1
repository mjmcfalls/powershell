# Set Netgear Driver registry setting according to the values below.
# HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}\
# DriverDesc = NETGEAR A6210 WiFi USB3.0 Adapter
# ComponentId = usb\vid_0846&pid_9053
# Channel Mode = 1    # ‘Channel Mode’ to 5G Only.
# MaxUserUsbSpeed = 3 # ‘Max USB Speed’ to USB 3.0
# PreferABand = 1     # ‘Prefer 5G’ is set to Enable.
# RoamTendency = 3    # Set ‘Roam Tendency’ to Aggressive.

$ErrorActionPreference= 'silentlycontinue'
$logFile = "$($PSScriptRoot)\NetGearDriverRegistry_$(get-date -f yyyyMMddHHmm).log"
$wifiProps = @{"Channel Mode" = 1
    "MaxUserUsbSpeed" = 3
    "PreferABand" = 1
    "RoamTendency" = 3
}
$searchPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}'
$targetDriverDesc = "NETGEAR"
$ComponentId = "usb\vid_0846&pid_9053"

# Start file logging to directory 
Out-File -FilePath $logFile -Append -InputObject "$(get-date -f 'yyyy-MM-dd HH:mm:ss') - Starting Log File"
# Test if $searchPath exists
if (Test-Path $searchPath){
    # Get Registry items
    $items = Get-ChildItem $searchPath -ErrorAction SilentlyContinue
    # Loop through registry items
    foreach($item in $items){
        Out-File -FilePath $logFile -Append -InputObject "$(get-date -f 'yyyy-MM-dd HH:mm:ss') - Checking if DriverDesc Property exists for $($item.Name)."
        # Check if DriverDesc property exists.
        if (Get-ItemProperty -path $item.PSPath -Name DriverDesc){
            Out-File -FilePath $logFile -Append -InputObject "$(get-date -f 'yyyy-MM-dd HH:mm:ss') - Checking DriverDesc registry value, $((Get-ItemProperty -path $item.PSPath -Name DriverDesc).DriverDesc), against target value,  $($targetDriverDesc)"
            # Check value of DriverDesc against targetDriverDesc value
            if ((Get-ItemProperty -path $item.PSPath -Name 'DriverDesc').DriverDesc -match $targetDriverDesc){
                Out-File -FilePath $logFile -Append -InputObject "$(get-date -f 'yyyy-MM-dd HH:mm:ss') - Checking ComponentId Property registry value: $((Get-ItemProperty -path $item.PSPath -Name 'ComponentId').ComponentId) against target value, $($ComponentId)"
                # Check ComponentId property value agains target ComponentId.
                if ((Get-ItemProperty -path $item.PSPath -Name 'ComponentId').ComponentId -like $ComponentId){
                    # Loop through hastable to check property values 
                    foreach($key in $wifiProps.Keys){
                        if (Get-ItemProperty -path $item.PSPath -Name $key){
                            if ((Get-ItemProperty -path $item.PSPath -Name $key).$key -ne $wifiProps[$key]){
                                # Write-Host "Updating $($item.Name)\$($key); Current value:$((Get-ItemProperty -path $item.PSPath -Name $key).$key); Target Value: $($wifiProps[$key])"
                                Out-File -FilePath $logFile -Append -InputObject ("$(get-date -f 'yyyy-MM-dd HH:mm:ss') - Updating $($item.Name)\$($key); Current value: $((Get-ItemProperty -path $item.PSPath -Name $key).$key); Target Value: $($wifiProps[$key])")
                                Set-ItemProperty -path $item.PSPath -Name $key -Value $wifiProps[$key]
                                }
                            else{
                                # Write-Host "No Changes made $($item.Name)\$($key); Current value: $((Get-ItemProperty -path $item.PSPath -Name $key).$key); Target Value: $($wifiProps[$key])"
                                Out-File -FilePath $logFile -Append -InputObject ("$(get-date -f 'yyyy-MM-dd HH:mm:ss') - No Changes made $($item.Name)\$($key); Current value: $((Get-ItemProperty -path $item.PSPath -Name $key).$key); Target Value: $($wifiProps[$key])")
                                }
                        }
                        else{
                            # Write-Host "Adding $($key) with value $($wifiProps[$key]) to $($item.Name)"
                            Out-File -FilePath $logFile -Append -InputObject ("$(get-date -f 'yyyy-MM-dd HH:mm:ss') - Adding ", $key, " with value ", $wifiProps[$key], "to ", $item.Name)
                            Set-ItemProperty -path $item.PSPath -Name $key -Value $wifiProps[$key]
                        }
                    }
                }
            }
        }        
    }
}
# Write to log if $searchPath does not exist.
else{
    Out-File -FilePath $logFile -Append -InputObject "$(get-date -f 'yyyy-MM-dd HH:mm:ss') - Invalid file Path: $($searchPath)"
}

