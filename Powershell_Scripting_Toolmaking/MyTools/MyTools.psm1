#### GET-OSInfo
function Get-OSInfo{
<#
.Synopsis
   Gets information about the operating system of a target computer
.DESCRIPTION
   Fetches and returns Computer name, OS Version, SP Version, OS Architecture, Manufacturer, Model, and BIOS Serial number
.EXAMPLE
   Get-OSInfo -computername Alpha 
.PARAMETER ComputerName
    Takes a single computer name or a list of computer names of which to fetch OS information
.PARAMETER ErrorLog
    Location and filename of the error log
.PARAMETER LogsError
    Switch to determine if errors should be logged or not logged.
#>
    [CmdletBinding()]
    param(
        [Parameter(
            HelpMessage="Provide up to 5 computer names",
            Mandatory=$True,
            ValueFromPipeLine=$True,
            ValueFromPipelineByPropertyName=$True)]
        [Alias('hostname')]
        [ValidateCount(1,5)]
        
        [string[]]$ComputerName,
        [Parameter(HelpMessage="Provide a path and file name to save error logs")]
        [string]$ErrorLog="C:\Scripts\Errors.txt",
        [Parameter(HelpMessage="Switch to enable logging")]
        [switch]$LogErrors=$false
    )
    Process{
        ForEach($computer in $ComputerName){
            Try{
                $os = Get-WmiObject -ErrorAction 'Stop' -Class Win32_OperatingSystem -ComputerName $computer 
                $cs = Get-WmiObject -ErrorAction 'Stop' -Class Win32_ComputerSystem -ComputerName $computer 
                $bios = Get-WmiObject -ErrorAction 'Stop' -Class Win32_BIOS -ComputerName $computer 
                #| Select-Object Version,ServicePackMajorVersion,BuildNumber,OSArchitecture

                $props = @{
                    'ComputerName'=$computer;
                    'OSVersion'=$os.version;
                    'SPVersion'=$os.servicepackmajorversion;            
                    'OSBuild'=$os.buildnumber;            
                    'OSArchitecture'=$os.osarchitecture;            
                    'Manufacturer'=$cs.manufacturer;             
                    'Model'=$cs.model;             
                    'BIOSSerial'=$bios.serialnumber}
                $obj = New-Object -TypeName PSObject -Property $props
                $obj.psobject.typenames.insert(0,'MyTools.OSInfo')
                Write-Output $obj
            }
            Catch{
                if($LogErrors){
                        "$($computer): $($_.Exception.Message)" | Out-File -Append $ErrorLog 
                    }
                Write-Warning "Connection to $($computer) failed"
            }
        }
    }
}

#### Get-DiskInfo
function Get-DiskInfo{
<#
.Synopsis
   Gets information about the disk subsystem of a target computer or computers
.DESCRIPTION
   Returns information about the disk subsystem of a target computer or computers based on the provided free space parameter.  Returns computer name, disk device ID, Free space of the disk, Size of disk, and Free space percentage.
.EXAMPLE
   Get-DiskInfo -ComputerName Alpha -DriveType 3 -percentFree 75 
.PARAMETER ComputerName
    Takes a single computer name or a list of computer names of which to fetch OS information.
.PARAMETER DriveType
    Expects a WMI drive type integer.  Defaults to 3.
.PARAMETER PercentFree
    Determines the if the drives with a specified amount of free space to return.
.PARAMETER ErrorLog
    Location and filename of the error log.
.PARAMETER LogsError
    Switch to determine if errors should be logged or not logged.
#>
    [CmdletBinding()]
    param(
        [Parameter(
            HelpMessage="Provide a list of up to 5 computers",
            Mandatory=$True,
            ValueFromPipeline=$True,
            ValueFromPipelineByPropertyName=$True)]
        [Alias("hostname")]
        [ValidateCount(1,5)]
        [string[]]$ComputerName,
        [Parameter(
            HelpMessage="Provide a integer drive type (WMI drive type integer)",
            Mandatory=$True)]
        [string]$DriveType=3,
        [Parameter(HelpMessage="Provide a percentage of free space which to filter drives on")]
        [int]$PercentFree=99,
        [Parameter(HelpMessage="Location and filename of an error log")]
        [string]$ErrorLog="C:\Scripts\Errors.txt",
        [Parameter(HelpMessage="Provide to enable logging to screen and log file")]
        [switch]$LogErrors=$false
    )
    Process{
        ForEach($computer in $ComputerName){
            Try{
                $disks = Get-WmiObject -ErrorAction 'Stop' -Class Win32_LogicalDisk -Filter "DriveType=$($DriveType)" -Computername $computer |
                    Where-Object { $_.FreeSpace / $_.Size * 100 -lt $PercentFree }

                ForEach($disk in $disks){
                    $props = @{
                        'ComputerName'=$computer;
                        'DeviceID'=$disk.deviceid;
                        'FreeSpace'=($disk.FreeSpace / 1GB -as [int]);
                        'Size'= ($disk.Size / 1GB);
                        'FreePercent'=($disk.FreeSpace / $disk.Size * 100 -as [int]);}
                    $obj = New-Object -TypeName PSObject -Property $props
                    $obj.psobject.typenames.insert(0,'MyTools.DiskInfo')
                    Write-Output $obj
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
}


#### Invoke-OSShutdown
function Invoke-OSShutdown{
<#
.Synopsis
   Targets a computer or computers in which to execute a shutdown, logoff, or restart against.
.DESCRIPTION
   Targets a computer or list of computers which a shutdown, logoff, or restart action will be targeted agains.
.EXAMPLE
   Invoke-OSShutdown -Computername Alpha -arg 0
.PARAMETER arg
    Integer which determines the type of event on the remote machine to trigger>
.PARAMETER ComputerName
    Takes a single computer name or a list of computer names of which to fetch OS information
.PARAMETER ErrorLog
    Location and filename of the error log
.PARAMETER LogsError
    Switch to determine if errors should be logged or not logged.
#>
    [CmdletBinding(
        SupportsShouldProcess=$True,
        ConfirmImpact='Medium'
    )]
    param(
        [Parameter(
            HelpMessage="LogOff, Restart, Shutdown, PowerOff action for remote computer",
            Mandatory=$True)]
        [ValidateSet("LogoInff","Restart","Shutdown","PowerOff")]
        [string]$Action,
        [Parameter(
            HelpMessage="Computer or list of computers to action shutdown events on",
            Mandatory=$True,
            ValueFromPipeLine=$True,
            ValueFromPipelineByPropertyName=$True)]
        [string[]]$Computername,
        [Parameter(HelpMessage="Location and filename of an error log")]
        [string]$ErrorLog="C:\Scripts\Errors.txt",
        [Parameter(HelpMessage="Provide to enable logging to screen and log file")]
        [switch]$LogErrors,
        [Parameter(HelpMessage="Force the remote shutdown event.")]
        [switch]$force
    )
    

    Process{
        $actionHashTbl = @{
            "LogOff"=0;
            "Restart"=1;
            "Shutdown"=2;
            "PowerOff"=8
        }
        ForEach($computer in $Computername){
            Try{
                if($force){
                    $act = $actionHashTbl[$action] + 4
                }
                else{
                    $act = $actionHashTbl[$action]
                }
                $results = Get-WmiObject -ErrorAction 'Stop' -Class Win32_Operatingsystem -ComputerName $computer |
                    Invoke-WmiMethod -Name Win32Shutdown -Arg $act
            }
            catch{
                if($LogErrors){
                    "$($computer): $($_.Exception.Message)" | Out-File -Append $ErrorLog
                    }
                Write-Warning "$($computer): $($_.Exception.Message)"
            }
        } 
    }
}


#### Get-ComputerVolumeInfo
function Get-ComputerVolumeInfo{
<#
.Synopsis
   Gets information about the operating system AND disks of a target computer or computers.
.DESCRIPTION
   Fetches information about the OS and disks of a target computer or computers.
.EXAMPLE
   Get-ComputerVolumeInfo -computername Alpha 
.PARAMETER ComputerName
    Takes a single computer name or a list of computer names of which to fetch OS information
#>
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeLine=$True,
            ValueFromPipelineByPropertyName=$True)]
        [string[]]$ComputerName
    )
    Process{
        ForEach($computer in $ComputerName){
            $os = Get-WmiObject Win32_OperatingSystem -ComputerName $computer 
            $disks = Get-WmiObject Win32_LogicalDisk -ComputerName $computer -Filter "DriveType=3" 
            $services = Get-WmiObject Win32_Service -ComputerName $computer 
            $procs = Get-WmiObject Win32_Process -ComputerName $computer 

            $props = @{'ComputerName'=$computer;            
                'OSVersion'=$os.version;             
                'SPVersion'=$os.servicepackmajorversion;            
                'LocalDisks'=$disks;             
                'Services'=$services;  
                'Processes'=$procs } 
            $obj = New-Object -TypeName PSObject -Property $props 
            Write-Output $obj 
        }
    }
}