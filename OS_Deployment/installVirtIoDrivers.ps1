<#
    .SYNOPSIS
        The script recusively searches through a provided directory for .inf files, then adds the files to a provided WIM file.
        Built to inject virtio drivers from Fedora into a Windows WIM file for use with Nutanix CE deployments.
    .DESCRIPTION
        Based on user provided parameters, then script will recursively search through a directory for *.inf files.
        The script will mount a WIM using DISM to inject the drivers, commit the changes, and unmount the WIM.

    .PARAMETER MountPoint
        The full path to an existing directory to mount a WIM using DISM.
    .PARAMETER ImageFile
        This parameter takes a full path to the WIM.
    .PARAMETER Index
        The index parameter takes an integer related to the index of the image in the WIM file to be mounted.
    .PARAMETER Path
        Path is the parameter of the directory to search for *.inf files to inject into the image.
    .PARAMETER Arch
        Arch is the architecture of the drivers to search.  The script looks at the full path name to determine the architecture of the *.inf
        files.  Supports "amd64" by default. 
    .PARAMETER OsVersion
        This is the string used to search the directory for a specific architecture.  
        Defaults to "2k16". Tested and supports '2k16', '2k12R2', '2k12', 'w10'.
    .PARAMETER Dsim
        Full path name to the DISM executable.  Defaults to C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe
        On new versions of Windows Server, there is a copy of DISM under \Windows which can be used, but may not support uplevel versions of Windows Server.
    .PARAMETER LogFile
        Name of the file in which to save logs.  Currently not implemented.
    .EXAMPLE
        .\installVirtIoDrivers.ps1 -Path C:\Users\admin\Downloads\virtio-win-0.1.141 -OSVersion w10 -MountPoint c:\temp -ImageFile "T:\ISO\install.wim" -Arch x86
        The example will search c:\Users\Admin\Download\virtio-win-0.1.141 for w10 x86 inf files. Next it will mount the WIM file at T:\ISO\install.wim to c:\temp,
        inject the drivers, and commit/unmount the WIM on completion.
    .NOTES
        Written to inject drivers from VirtIO into a Windows WIM file for deployment on Nutanix.  It should work with with any directory structure which uses 
        Folder\OS\processorArch format.  
    #>

[CmdletBinding(
    SupportsShouldProcess = $True
)]
param(
    [string]$MountPoint,
    [string]$ImageFile,
    [int]$Index = 0,
    [string]$Path,
    [string]$Arch = "amd64",
    # [Parameter(Mandatory = $true)]
    [string]$OSVersion = '2k16',
    # [ValidateSet('2k16', '2k12R2', '2k12', 'w10')]
    [string]$Dism = "`"C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe`"",
    [string]$LogFile = "InsertDriversDism.log"
)

# $dism = 
# $MountPoint = "`"C:\packer\temp`""
# $ImageFile = `"C:\Users\Administrator\Downloads\Server2019_20190523_SERVER_EVAL_x64FRE_en-us\sources\install.wim`"
# $Index = 4
$MountCmd = @"
&$($dism) /Mount-Image /ImageFile:`"$($ImageFile)`"  /index:$($Index) /MountDir:$($MountPoint)
"@
$UnMountCmd = @"
&$($dism) `/Unmount-Image `/MountDir:`"$($MountPoint)`" `/Commit
"@
$DriverCmd = @"
&$($dism) /Image:`"$($MountPoint)`" /Add-Driver /Driver:
"@
$InfRegex = "(\.inf)$"
$Drivers = New-Object System.Collections.Generic.List[System.Object]

Write-Host "Searching for $($OSversion) drivers"
ForEach ($item in $(Get-ChildItem $Path -Recurse)) {
    if ($item.FullName.Contains($OSVersion) -And $item.FullName.Contains($Arch)) {
        if (-Not $item.PSIsContainer) {
            if ($item.Name -Match $InfRegex) {
                # Write-Host $item.FullName
                $Drivers.Add( @{ "File" = $item.FullName; "DriverCmd" = ($DriverCmd + "`"$($item.FullName)`"") })
            }
        }
    }
}

Write-Host "Mounting image"
Invoke-Expression $MountCmd

foreach ($Driver in $Drivers) {
    Write-Host "Inserting $($Driver.File)"
    Invoke-Expression $Driver.DriverCmd
}

Write-Host "Unmount and commit changes"
Invoke-Expression $UnMountCmd