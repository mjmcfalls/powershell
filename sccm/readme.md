### Scripts run by SCCM or for SCCM

checkGeneric.ps1 - Powershell script run using CCM cmdlets to apply a SCCM script to a csv of computers.
runGenericCheck.bat - Batch file to run execute checkGeneric.ps1
Remote-set_registy_key_auto_login.ps1 - Script to check registry settings on a csv of computers.  Reworked to checkGeneric.ps1 to run from SCCM - turned out to be faster, more reliable, and more in line with the team knowledge.