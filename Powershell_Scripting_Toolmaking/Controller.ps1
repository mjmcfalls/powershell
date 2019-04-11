# Requires -Module MyTools
While($True){
    Write-Host "1. Get System Information"
    Write-Host "2. Get Disk Information"
    Write-Host "3. Restart a Computer"
    Write-Host "0. Exit"
    $choice = Read-Host "Enter a Selection: "
    If ($choice -eq 0){
        Write-Host "Bye!"
        exit
    }
    elseif($choice -eq 1 -or $choice -eq 2 -or $choice -eq 3){
        $computers = @()
        do {
            $pc = Read-Host "Enter a computer name or blank line to continue: "
            if ($pc -ne ''){
                $computers += $pc
            }

        } until ( $pc -eq '')

        switch($choice){
            1 { Get-OSInfo -computername $computers }
            2 { Get-DiskInfo -computername $computers }
            3 { Invoke-OSShutdown -computername $computers -action Restart }
        }
        Write-Host "`n"
    }
    else {
        Write-Host "Invalid Selecction"
    }
}