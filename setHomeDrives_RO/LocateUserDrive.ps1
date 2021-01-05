
param(
    [parameter(mandatory = $false)][string]$username
)

$userStopWatch = [System.Diagnostics.StopWatch]::StartNew()
$Out = "C:\Scripts\check_out.txt"
# Start-Transcript -path $Out -append
#$files = Get-Content -Path 'C:\Scripts\UserIDList.txt'
$server = "\\server\usersHome"
$sites = @("users", "users2", "users3")


foreach ($userID in $username) {
    foreach ($element in $sites) {
        if (Get-ChildItem -Path "$server\$element" -Directory -Name | Where-Object { $_ -match "$($userID)"}) {
            Write-Host -ForegroundColor green "$userID found in $element" 
        }
        else {
            Write-Host  "$userID not found in $element"   
        }
    }
}



# Stop-transcript
$userStopWatch.Stop()
$userStopWatch.Elapsed
Write-Host "Users Found in $($userStopWatch)"
