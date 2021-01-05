
Function Write-Log {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $False)]
        [ValidateSet("INFO", "WARN", "ERROR", "FATAL", "DEBUG")]
        [String]
        $Level = "INFO",
        [Parameter(Mandatory = $True)]
        [string]
        $Message,
        [Parameter(Mandatory = $False)]
        [string]
        $logfile
    )

    $Stamp = (Get-Date).toString("yyyy/MM/dd HH:mm:ss")
    $Line = "$Stamp $Level $Message"
    If ($logfile) {
        Add-Content $logfile -Value $Line
    }
    Else {
        Write-Output $Line
    }
}

Function Search-Wsus {
    param(
        [string]$uri,
        [int]$port,
        [string[]]$searchItems
    )

    $wsussrcdata = New-Object System.Collections.Generic.List[System.Object]

    [void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")

    $script:Wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($uri, $false, $port)
    $updatescope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
    $computerscope = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
    $updatescope.ApprovedStates = [Microsoft.UpdateServices.Administration.ApprovedStates]::Any
    $updatescope.IncludedInstallationStates = [Microsoft.UpdateServices.Administration.UpdateInstallationStates]::NotInstalled

    foreach ($item in $searchItems) {
        $updates = $wsus.SearchUpdates($item)
        $update = $updates[0]
        $computers = $update.GetUpdateInstallationInfoPerComputerTarget($computerScope) | Select @{L = 'Client'; E = { $wsus.GetComputerTarget(([guid]$_.ComputerTargetId)).FulldomainName } },
        @{L = 'TargetGroup'; E = { $wsus.GetComputerTargetGroup(([guid]$_.UpdateApprovalTargetGroupId)).Name } },
        @{L = 'Update'; E = { $wsus.GetUpdate(([guid]$_.UpdateId)).Title } }, UpdateInstallationState, UpdateApprovalAction

        Foreach ($computer in $computers) {
            $psobj = [PSCustomObject]@{
                Client                  = ""
                TargetGroup             = ""
                Update                  = ""
                UpdateInstallationState = ""
                UpdateApprovalAction    = ""
            }
            $psobj.Client = $computer.client
            $psobj.TargetGroup = $computer.TargetGroup
            $psobj.Update = $computer.Update
            $psobj.UpdateInstallationState = $computer.UpdateInstallationState
            $psobj.UpdateApprovalAction = $computer.UpdateApprovalAction
            $wsussrcdata.add($psobj)
        }
    }
    $wsussrcdata 
}

$stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$updateData = New-Object System.Collections.Generic.List[System.Object]
$summaryData = New-Object System.Collections.Generic.List[System.Object]
$kbs = '4571729', '4571736', '4571702', '4571703', '4571723', '4571694', '4565349', '4565351', '4566782'
$wsusServer = "Server"
# Write-Log -Level "INFO" -Message "Pulling WSUS data"
$wsussrcdata = Search-Wsus -uri $wsusServer -port 80 -searchItems $kbs
# $wsussrcdata | Export-CSV -NoTypeInformation "WsusSrcData_$(Get-Date -f yyyyMMddHHMMss).csv"

$groups = $wsussrcdata | Select-Object TargetGroup -Unique 
$states = $wsussrcdata | Select-Object UpdateInstallationState -Unique
$groupTotals = $wsussrcdata | Group-Object TargetGroup -AsHashTable -AsString

foreach ($group in $groups) {
    $temp = @{}
    $temp.add("Group", $group.TargetGroup)
    foreach ($state in $states) {
        $temp.add($state.UpdateInstallationState, $null)
    }
    "Group: $($group.TargetGroup)"
    "Group Total: $(($groupTotals."$($group.TargetGroup)" | Measure-Object).count)"
    $temp.add("Total", $(($groupTotals."$($group.TargetGroup)" | Measure-Object).count))
    $summaryData.Add($temp)
}
# $summaryData
$servers = $wsussrcdata | Select-Object Client -Unique | Sort-Object -Property Client

# Write-Log -Level "INFO" -Message "Processing data for patch state"
foreach ($server in $servers) {
    # Write-Log -Level "INFO" -Message "Processing $($server.Client)"
    $serverObj = [PSCustomObject]@{
        Client       = ""
        TargetGroup  = ""
        InstallState = ""
    }
    $serverObj.Client = $server.Client
    $targetserver = $wsussrcdata | Where-Object { $_.Client -like $server.Client }
    # $targetserver.length
    if ($targetserver) {
        $serverObj.TargetGroup = $targetserver[0].TargetGroup
        if ( $targetserver  | Where-Object { $_.UpdateInstallationState -eq "Installed" } ) {
            # $targetserver | Where-Object { $_.UpdateInstallationState -eq "Installed" }
            $serverObj.InstallState = "Installed"
        }
        elseif ( $targetserver | Where-Object { $_.UpdateInstallationState -eq "NotInstalled" } ) {
            # $targetserver | Where-Object { $_.UpdateInstallationState -eq "NotInstalled" }
            $serverObj.InstallState = "NotInstalled"
        }
        elseif ($targetserver | Where-Object { $_.UpdateInstallationState -eq "Unknown" } ) {
            # $targetserver | Where-Object { $_.UpdateInstallationState -eq "Unknown" } 
            $serverObj.InstallState = "Unknown"
        }
        else {
            # $targetserver | Format-List
            $serverObj.InstallState = "NotApplicable"
        }
    }
    $updateData.add($serverObj)
}

$countHshtbl = $updateData | Group-Object -Property TargetGroup, InstallState -AsHashTable -AsString

foreach ($key in $countHshTbl.keys) {
    $group, $state = $key.split(",").Trim()
    foreach ($item in $summaryData) {
        # Write-Log -Level "INFO" -Message "Searching for $($group)"
        if ($group -eq $item.Group) {
            # Write-Log -Level "INFO" -Message "Updating $($group) - $($state)"
            $item.$state = ( $countHshtbl.$key | Measure-Object ).Count
            break
        }
    }
}


# END
$summaryData

# Graphing logic
# Add-Type -AssemblyName System.Windows.Forms
# Add-Type -AssemblyName System.Windows.Forms.DataVisualization

# $Chart = New-object System.Windows.Forms.DataVisualization.Charting.Chart
# $ChartArea = New-Object System.Windows.Forms.DataVisualization.Charting.ChartArea
# $Series = New-Object -TypeName System.Windows.Forms.DataVisualization.Charting.Series
# $ChartTypes = [System.Windows.Forms.DataVisualization.Charting.SeriesChartType]
# $Series.ChartType = $ChartTypes::Pie

# $Chart.Series.Add($Series)
# $Chart.ChartAreas.Add($ChartArea)

# $Chart.Series['Series1'].Points.DataBindXY("Detect", ($updateData | Select InstallState))

# $ChartTitle = New-Object System.Windows.Forms.DataVisualization.Charting.Title
# $ChartTitle.Text = 'Top 5 Processes by Working Set Memory'
# $Font = New-Object System.Drawing.Font @('Microsoft Sans Serif','12', [System.Drawing.FontStyle]::Bold)
# $ChartTitle.Font =$Font
# $Chart.Titles.Add($ChartTitle)


$stopwatch.Stop()
Write-Log -Level "INFO" -Message "Wsus report generated in $([math]::Round($stopwatch.Elapsed.TotalSeconds,$decimalPlace)) seconds."

