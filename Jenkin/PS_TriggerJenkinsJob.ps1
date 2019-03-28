# Variables
$JenkinsURL = "http://URL"
$JobName = "JenkinsJobName"
$JobToken = "JobToken"
$User = "JenkinsUserName"
$token = "TOKEN"
$Auth = "$($User):$($token)"

# Prepare to get CSRF Crumb
$Bytes = [System.Text.Encoding]::UTF8.GetBytes($Auth)
$Base64bytes = [System.Convert]::ToBase64String($Bytes)
$Headers = @{ "Authorization" = "Basic $Base64bytes"}
# Get CSRF Crumb
$CrumbIssuer = "$JenkinsURL/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,`":`",//crumb)"
$Crumb = Invoke-WebRequest -UseBasicParsing $CrumbIssuer -Headers $Headers
# Process CSRF Crumb
$Regex = '^Jenkins-Crumb:([A-Z0-9]*)'
$Matches = @([regex]::matches($crumb, $regex, 'IgnoreCase'))
$RegCrumb = $Matches.Groups[1].Value
$Headers.Add("Jenkins-Crumb", "$RegCrumb")
# Trigger Jenkins job
$FullURL = "$JenkinsURL/job/$JobName/build?token=$JobToken"
Invoke-WebRequest -UseBasicParsing $FullURL -Method POST -Headers $Headers
