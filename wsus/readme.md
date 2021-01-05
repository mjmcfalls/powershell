### Wsus Scripts

createWsusReport.ps1 - Searches a specific WSUS server for a list of KBs, and returns information about the list of KBs.
getSearchWsusUpdates.ps1 - Updated version of createWsusReports which takes the WSUS URI, port, and a list of KBs to search for, then returns a psobj on to the pipeline.

ReportBySecurityGroup\getWsusUpdateData.ps1
This script takes an Active Directory security group, the pulls the patching information from WSUS, and the last reboot times from Solarwinds Orion, then emails out a report.   The report will run without the Orion server; the last reboot fields will be blank.