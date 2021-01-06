$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

Describe "Autolaunch scripts tests" {
  
    $apptests = @(
        @{TestName = "Autolaunch - Surginet"; app = "Surginet"; value = "surginet" }
        @{TestName = "Autolaunch - Firstnet"; app = "Firstnet"; value = "firstnet" }
    )
    $apptests = @(
        @{TestName = "Autolaunch - Surginet"; app = "Surginet"; value = "surginet" }
        @{TestName = "Autolaunch - Firstnet"; app = "Firstnet"; value = "firstnet" }
    )
    It "Start-App for <TestName>" -TestCases $apptests {
        param(
            $app,
            $value
        )
        Start-App -app $app | Should -be $value
    }
    It "Get-ProcessCount Tests"{

        Get-ProcessCount | Should -be $null
    }

    It "Invoke-Main for <TestName>" -TestCases $apptests {
        param(
            $app,
            $value
        )
        Invoke-Main -app $app| Should -be $value
    }

}
