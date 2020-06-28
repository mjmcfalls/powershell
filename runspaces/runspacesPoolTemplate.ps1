$Scriptblock = {
    param($text)
    # New-Item -Name $Name -ItemType File
    $text
}

$MaxThreads = 5
$RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads)
$RunspacePool.Open()
$jobs = New-Object System.Collections.ArrayList

1..1000 | Foreach-Object {
    $PowerShell = [powershell]::Create()
    $PowerShell.RunspacePool = $RunspacePool
    [void]$PowerShell.AddScript($ScriptBlock)
    [void]$Powershell.AddArgument("Test $($_)")
    [void]$jobs.Add((
            [pscustomobject]@{
                PowerShell = $PowerShell
                Handle     = $PowerShell.BeginInvoke()
            }
        ))
}

while ($jobs.Handle.IsCompleted -contains $false ) {
    # Write-Host "." -NoNewline
    Start-Sleep -Milliseconds 100

}

ForEach ($job in $jobs ){
    $job.powershell.EndInvoke($job.handle)
    $job.PowerShell.Dispose()
}

$RunspacePool.Close()

