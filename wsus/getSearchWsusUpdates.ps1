Function Search-Wsus {
    param(
        [string]$uri,
        [int]$port,
        [string[]]$searchItems
    )

    $outdata = New-Object System.Collections.Generic.List[System.Object]

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
            $outdata.add($psobj)
        }
    }
    $outdata 
}

# Example usage
# $kbs = '4571729', '4571736', '4571702', '4571703', '4571723', '4571694', '4565349', '4565351', '4566782'
# $outdata = Search-Wsus -uri "MHSServerWSUS" -port 80 -searchItems $kbs
# Into a Csv: Search-Wsus -uri "MHSServerWSUS" -port 80 -searchItems $kbs | Export-Csv -NoTypeInformation out.csv