Set-StrictMode -Version Latest

function Get-IsAdmin()
{
    $CurrentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $CurrentUserPrincipal = New-Object System.Security.Principal.WindowsPrincipal($CurrentUser)
    return $CurrentUserPrincipal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-ProcessOutput {
    param (
        [string]
        $Path,

        [string]
        $WorkingDirectory,

        [string]
        $Arguments,

        [switch]
        $LaunchWindow,

        [switch]
        $Elevate,

        [switch]
        $DoNotWait
    )
    
    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $Path
    $processInfo.Arguments = $Arguments
    $processInfo.WorkingDirectory = $WorkingDirectory

    if ($LaunchWindow -eq $true) {
        # $processInfo.RedirectStandardError = $true
        # $processInfo.RedirectStandardOutput = $true
        $processInfo.UseShellExecute = $true
        $processInfo.CreateNoWindow = $false
        $processInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Maximized
    }
    else 
    {
        $processInfo.RedirectStandardError = $true
        $processInfo.RedirectStandardOutput = $true
        $processInfo.UseShellExecute = $false
        $processInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Maximized
    }

    if ($Elevate) {
        $processInfo.Verb = "runas"
    }

    $outputBuilder = New-Object -TypeName System.Text.StringBuilder
    $errorBuilder = New-Object -TypeName System.Text.StringBuilder
    $dataReceivedEvent = {
        if (! [String]::IsNullOrEmpty($EventArgs.Data)) {
            $Event.MessageData.AppendLine($EventArgs.Data)
        }
    }

    $process = New-Object System.Diagnostics.Process
    $outputEvent = Register-ObjectEvent -InputObject $process -Action $dataReceivedEvent -EventName 'OutputDataReceived' -MessageData $outputBuilder
    $errorEvent = Register-ObjectEvent -InputObject $process -Action $dataReceivedEvent -EventName 'ErrorDataReceived' -MessageData $errorBuilder

    try {
        $process.StartInfo = $processInfo
        if (-not $process.Start()) {
            return $null
        }

        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()

        if (-not $DoNotWait) {
            $process.WaitForExit()
        }

        if ($LaunchWindow) {
            return $null
        }

        return @{
            Succeeded = $process.ExitCode -eq 0
            StandardOutput = $outputBuilder.ToString()
            StandardError = $errorBuilder.ToString()
        }
    }
    finally {
        Unregister-Event -SourceIdentifier $outputEvent.Name
        Unregister-Event -SourceIdentifier $errorEvent.Name
    }
}

function Invoke-ElevatedCommand {
    param (
        [ScriptBlock]
        $Command,

        [switch]
        $NoExit
    )

    if (Get-IsAdmin) {
        & $Command
        return
    }

    Write-Host "Command needs elevation, elevating..." -ForegroundColor Green

    $commandToElevate = $Command.ToString()

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo("$PSHome\PowerShell.exe")
    $processInfo.Verb = "runas"
    $processInfo.WorkingDirectory = $WorkingDirectory
    $processInfo.UseShellExecute = $true
    $processInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Normal
    if ($NoExit) {
        $processInfo.Arguments = "-NoExit $commandToElevate"
    } else {
        $processInfo.Arguments = $commandToElevate
    }

    $process = New-Object System.Diagnostics.Process

    try {
        $process.StartInfo = $processInfo
        if (-not $process.Start()) {
            return $null
        }
        
        if ($process.ExitCode -eq -0) {
            Write-Host "and command ran successfully." -ForegroundColor Green
        } else {
            Write-Host "but command failed." -ForegroundColor Red
        }
    }
    catch { 
        Write-Host "Couldn't elevate!" -ForegroundColor Red
        return
    }
}

Export-ModuleMember -Function Get-IsAdmin, Get-ProcessOutput, Invoke-ElevatedCommand