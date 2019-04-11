Workflow Provision1{
    parallel{
        Get-Service | Where-Object Status -eq Running
    }

    Sequence{
        New-Item -Path HKLM:\Software\Custom -Force
        New-ItemProperty -Path HKLM:\Software\Custom -Name "Test" -Value 0 -Force
    }

}


