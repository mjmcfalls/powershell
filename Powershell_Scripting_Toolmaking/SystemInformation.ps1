# Requires -module MyTools
[CmdletBinding()]
param(
    [string[]]$ComputerName,
    [string]$Path
)

$css = @'
<style> 
    body {     
        width: 90%;    
        margin-top: 10px;     
        margin-bottom: 50px;     
        margin-left: auto;     
        margin-right: auto;     
        padding: 0px;  
        border-width: 0px; 
    } 
    table {  
        border-width: 1px;  
        border-style: solid;  
        border-color: black; 
    tr:Nth-Child(Even) {  Background-Color: lightgrey; } 
    tr:Hover TD {  Background-Color: cyan; } 
 </style> 
'@ 

ForEach($computer in $computerName){
    $oPath = Join-Path -Path $Path -ChildPath "$($computer).html"
    $os = Get-OSInfo -ComputerName $computer | ConvertTo-HTML -PreContent '<h2>System Information</h2>' -Fragment | Out-String
    $disk = Get-DiskInfo -ComputerName $computer -DriveType 3| ConvertTo-HTML -PreContent '<h2>Disk Information</h2>' -Fragment | Out-String
    $processes = Get-Process -ComputerName $computer | 
        ConvertTo-HTML -Precontent '<h2>Processes</h2>' -Fragment -Property Handles,NPM,PM,CPU,ID,SI,Name | 
        Out-String
    $services = Get-Service -ComputerName $computer | ConvertTo-HTML -PreContent '<h2>Services</h2>' -Fragment -Property Status,Name,DisplayName | Out-String

    $params = @{
        'Head'="<title>Report for $($computer)</title>$($css)";
        'PreContent'="<h1>Information for $($computer)</h1>";
        'PostContent'=$os, $disk, $processes, $services;    
    }
    ConvertTo-HTML @params | Out-File -File $oPath
}