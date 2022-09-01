[CmdletBinding(SupportsShouldProcess=$true)]
param([switch]$Apply, [switch]$Force)

Set-StrictMode -Version 3.0

Clear-Host
$script:WhitelistFolder = $PSScriptRoot;
$script:WhitelistName = "$($env:COMPUTERNAME).txt"
$script:WhitelistedPath = Join-Path $script:WhitelistFolder -ChildPath $script:WhitelistName
$script:WhitelistString = [System.IO.File]::ReadAllLines($script:WhitelistedPath)

$whitelist = @()
$blacklist = @()

for ( $i = 0; $i -lt $Script:WhitelistString.Length; $i++ ) {
    $line = $Script:WhitelistString[$i].Trim()

    if([string]::IsNullOrWhiteSpace($line) -or $line[0] -eq "#") 
    {
        continue
    }

    if($line.Contains("#"))
    {
        $line = $line.Substring(0, $line.IndexOf("#")).Trim()
    }

    if($line[0] -eq "-") 
    {
        $line = $line.Substring(1).Trim()
        $blacklist += $line

        continue
    }

    if($line[0] -eq "+") 
    {
        $line = $line.Substring(1).Trim()
    }

    $whitelist += $line
}

Get-AppxPackage | ForEach-Object {
    if( $blacklist -icontains $_.Name ) 
    {
        Write-Host "App blacklisted: " -NoNewline
        Write-Host $_.Name -ForegroundColor Red -NoNewline

        if($Apply -or $Force) 
        {
            Remove-AppPackage $_ | Out-Host
            Write-Host " removed."
            return
        }

        Write-Host " will be removed if applied."
    }
    elseif( $whitelist -inotcontains $_.Name )
    {
        Write-Host "App is not whitelisted: " -NoNewline
        Write-Host $_.Name -ForegroundColor Yellow -NoNewline

        if($Force) 
        {
            Remove-AppPackage $_ | Out-Host
            Write-Host " removed."
            return
        }

        Write-Host " will be removed if forced."
    }
    else
    {
        Write-Verbose "App whitelisted: $_.Name"
    }
}