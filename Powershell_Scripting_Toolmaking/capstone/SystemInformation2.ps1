# Requires -module CorpTools
[CmdletBinding()]
param(
    [string]$ComputerName,
    [string]$OutFilePath='C:\Scripts\reports'
)

$css = @" 
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
    border-collapse: collapse; 
    } 
th {  
    border-width: 1px;  
    padding: 3px;  
    border-style: solid;  
    border-color: black;  
    background-color: lightblue; 
    } 
td {  
    border-width: 1px;  
    padding: 3px;  
    border-style: solid; 
 border-color: black; 
 } 
 tr:Nth-Child(Even) {  Background-Color: lightgrey; } 
tr:Hover TD {  Background-Color: cyan; } 
</style>
"@

$oPath = Join-Path -Path $OutFilePath -ChildPath "$($ComputerName)_$(Get-Date -Format 'FileDate').html"
$services = Get-StartedServices -ComputerName $ComputerName | ConvertTo-HTML -PreContent '<h2>Running Services</h2>' -Fragment | Out-String
$nics = Get-NetAdaptInfo -ComputerName $ComputerName | ConvertTo-Html -PreContent '<h2>Network Adapaters</h2>' -Fragment | Out-String
$os = Get-SystemInfo -ComputerName $ComputerName | ConvertTo-HTML -PreContent '<h2>System Information</h2>' -Fragment | Out-String

#$params = @{
#    'Head'="<title>Report for $($ComputerName)</title>$($css)";
#    'PreContent'="<h1>Information for $($ComputerName)</h1>";
#    'PostContent'=$os, $nics, $services;    
#}

#ConvertTo-HTML @params | Out-File -File $oPath

ConvertTo-HTML -Head "<title>Report for $($ComputerName)</title>$($css)" `
    -PreContent "<h1>Information for $($ComputerName)</h1>" `
    -PostContent $os, $nics, $services | Out-File $oPath