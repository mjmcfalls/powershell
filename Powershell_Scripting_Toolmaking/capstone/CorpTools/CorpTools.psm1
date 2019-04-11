# This should query Win32_NetworkAdapter from WMI, including only physical adapters (PhysicalAdapter=True). 
# Display the AdapterType, Speed (in gigabytes, but do not include a ‘GB’ identifier), the NetConnectionID, and the MACAddress. 
# Keep in mind that a computer may have more than one adapter installed. The computer name should also be included as a property of each adapter
function Get-NetAdaptInfo{
    [CmdletBinding()]
    param(
        [string[]]$ComputerName,
        [switch]$LogErrors,
        [string]$ErrorLog="c:\Scripts\Logs\CorpTools.log"
    )
    Process{
        ForEach($computer in $Computername){
            Try{
                $nics = Get-WmiObject -ErrorAction 'Stop' -Class Win32_NetworkAdapter -ComputerName $computer -Filter "PhysicalAdapter=True"
                ForEach($nic in $nics){
                    $props = @{
                        'Computername'=$computer;
                        'AdapterType'=$nic.AdapterType;
                        'Speed'=$nic.Speed / [Math]::Pow(10,9);
                        'NetConnectionID'=$nic.DeviceID;            
                        'MACAddress'=$nic.MACAddress
                        }
                    $obj = New-Object -TypeName PSObject -Property $props
                    $obj.psobject.typenames.insert(0,'CorpTools.NetAdaptInfo')
                    Write-Output $obj
                }
            }
            Catch {
                if($LogErrors){
                    "$($computer): $($_.Exception.Message)" | Out-File -Append $ErrorLog 
                }
                Write-Warning "$($computer): $($_.Exception.Message)"
            }
    
        }
    }
}



# This should query the following classes and return a unified object containing:  
# From Win32_ComputerSystem, include the computer name, DNSHostName, AutomaticManagedPagefile, Manufacturer, Model, and Domain.  
# From Win32_BIOS, include the SerialNumber, naming the property BIOSSerial.  
# From Win32_BaseBoard, include the Product (naming the property BaseBoardProduct) and Manufacturer (naming the property BaseBoardMfgr).
function Get-SystemInfo {
    [CmdletBinding()]
    param(
        [string[]]$ComputerName,
        [switch]$LogErrors,
        [string]$ErrorLog="c:\Scripts\Logs\CorpTools.log"
    )
    Process{
        ForEach($computer in $Computername){
            Try{
                $os = Get-WmiObject -ErrorAction 'Stop' -Class Win32_ComputerSystem -ComputerName $computer
                $bios = Get-WmiObject -ErrorAction 'Stop' -Class Win32_BIOS -ComputerName $computer
                $base = Get-WmiObject -ErrorAction 'Stop' -class Win32_BaseBoard -ComputerName $computer

                $props = @{
                    'ComputerName'=$computer;
                    'DnsHostName'=$os.DNSHostName;
                    'AutomaticManagedPageFile'=$os.AutomaticManagedPagedFile;
                    'Manufacturer'=$os.Manufacturer;
                    'Model'=$os.Model;
                    'Domain'=$os.Domain;
                    'BIOSSerial'=$bios.SerialNumber;
                    'BaseBoardProduct'=$base.Product;
                    'BaseBoardMfgr'=$base.Manufacturer
                }
                $obj = New-Object -TypeName PSObject -Property $props
                $obj.psobject.typenames.insert(0,'CorpTools.SystemInfo')
                Write-Output $obj
            }
            Catch {
                if($LogErrors){
                    "$($computer): $($_.Exception.Message)" | Out-File -Append $ErrorLog 
                }
                Write-Warning "$($computer): $($_.Exception.Message)"
            }
        }
    }
}


# This should query all running services, using either Get-Service, or the Win32_Service WMI class. Include the 
# computer name, the service name, and the service’s executable filename.  
function Get-StartedServices {
    [CmdletBinding()]
    param(
        [string[]]$ComputerName,
        [switch]$LogErrors,
        [string]$ErrorLog="c:\Scripts\Logs\CorpTools.log"
    )
    Process{
        
        Try{
            ForEach($computer in $computerName){
                $services = Get-Service -ComputerName $computer -ErrorAction 'Stop'| Where-Object { $_.Status -eq "Running" }
                ForEach($service in $services){
                    $props = @{
                        'ComputerName'=$computer;
                        'ServiceDisplayName'=$service.DisplayName;
                        'ServiceExecutableName'=$service.ServiceName;
                        'ServiceStatus'=$service.Status
                    }
                    $obj = New-Object -TypeName PSObject -Property $props
                    $obj.psobject.typenames.insert(0,'CorpTools.RunningServices')
                    Write-Output $obj
                }
            }
        }
        Catch{
            if($LogErrors){
                "$($computer): $($_.Exception.Message)" | Out-File -Append $ErrorLog 
            }
            Write-Warning "$($computer): $($_.Exception.Message)"
        }

    }

}