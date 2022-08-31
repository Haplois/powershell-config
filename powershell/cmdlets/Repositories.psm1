Set-StrictMode -Version Latest

function Test-GPG
{
    if (-not ($null -eq (Get-Process -Name "gpg-agent" -ErrorAction Ignore)))
    {
        Write-Host "`e[32mGPG agent is already alive."
        return
    }

    Write-Host "Reviving GPG agent..." -NoNewline
    Start-Process -FilePath "$global:DrivePath\Programs\GnuPG\App\bin\gpg-agent.exe" `
                  -ArgumentList "--homedir", "$env:APPDATA\gnupg\", "--daemon" `
                  -WindowStyle Hidden 

    Write-Host "`e[2K`r`e[1m`e[32mGPG agent revived."
}

function Get-RepositoryPath 
{
    param (
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("vstest", "testfx", "sdk", "runtime", "aep", "arcade", "betracker", "vs", "tmp", "mstest", "karga")]
        [string]
        $name,
        
        [bool]
        $fork = $false
    )

    $path = "$global:DrivePath\git\hub\";

    if ($fork) {
        $path = $path + 'haplois\-';
    }
    
    switch ($name) {
        "aep" { $path = "$global:DrivePath\git\hub\" }
        "betracker" { $path = "$global:DrivePath\git\hub\" }
        "karga" { $path = "$global:DrivePath\git\hub\" }
        "tmp" { $path = "$global:DrivePath\git\tmp\" }
        "vs" { $path = "$global:DrivePath\git\dd\" }
        "mstest" { $path = "$global:DrivePath\git\dd\" }
    }

    $repository = [System.IO.Path]::GetFullPath($name);
    if ($repository.EndsWith("\")) {
        $repository = $repository.Substring(0, $repository.Length - 1);
    }

    $repository = [System.IO.Path]::GetFileName($repository);
    switch ($repository) {
        "vstest" { $path = $path + 'microsoft\vstest'; }
        "testfx" { $path = $path + 'microsoft\testfx'; }
        "sdk" { $path = $path + 'dotnet\sdk'; }
        "runtime" { $path = $path + 'dotnet\runtime'; }
        "arcade" { $path = $path + 'dotnet\arcade'; }
        "aep" { $path = $path + 'haplois\aep'; }
        "betracker" { $path = $path + 'haplois\betracker'; }
        "karga" { $path = $path + 'haplois\karga'; }
        "vs" { $path = $path + 'vs'; }
        "mstest" { $path = $path + 'mstest'; }
    }

    if (-not (Test-Path $path) -and $fork -eq $true) {
        Write-Host "Couldn't locate a fork for $name, " -ForegroundColor DarkGray -NoNewline

        $clonePath = Get-RepositoryPath -name $name -fork $false

        if(Test-Path $clonePath) {
            Write-Host "located the clone instead." -ForegroundColor Green

            return $clonePath;
        }

        Write-Host "also no clone can be found!" -ForegroundColor Red;
    }

    return $path;
}

function Set-LocationToRepository 
{
    param
    (
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("vstest", "testfx", "sdk", "runtime", "aep", "arcade", "betracker", "vs", "mstest", "karga")]
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=0)]
        $repository,

        [Switch]
        $upstream
    )

    Set-Location -Path (Get-RepositoryPath -name $repository -fork (-not $upstream.IsPresent))
}

function Set-LocationToIssue 
{
    param (
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("vstest", "testfx", "sdk", "runtime", "aep", "arcade", "betracker", "vs", "mstest", "feedback")]
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=0)]
        $repository,

        [int]
        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true,Position=1)]
        $issue,

        [string]
        $clone = $null
    )

    $path = Get-RepositoryPath -name "tmp" -fork $false
    $path = Join-Path -Path $path -ChildPath "$repository\issue-$issue"
    $new = $false

    if(-not (Test-Path $path))
    {
        New-Item -ItemType Directory -Path $path | Out-Null
        $new = $true
    }

    Set-Location $path

    if($new)
    {
        if([string]::IsNullOrWhiteSpace($clone))
        {
            git init --initial-branch="$repository/repro/issue-$issue"
        } else {
            git clone $clone $path
        }
    }
}

function Get-GitLog 
{
    param (
        [int]
        $Number,

        [string]
        $Branch 
    )
    
    $command = "git log"

    if (-not [string]::IsNullOrWhiteSpace($Branch)) {
        $command = "$command -b `"$Branch`""
    }

    if ($Number -gt 0) {
        $command = "$command -n $number"
    }
    
    Invoke-Expression "$command --pretty=oneline"
}

function Import-GitRepo 
{
    param (
        [string]
        $Upstream,

        [string]
        $Branch
    )
    
    $command = "git clone"

    if (-not [string]::IsNullOrWhiteSpace($Branch)) {
        $command = "$command --branch `"$Branch`""
    }

    Invoke-Expression "$command `"$Upstream`""
}


function Get-GitStatus 
{   
    Invoke-Expression "git status"
}

function Start-Dogfood 
{
    param (
        [ValidateSet("fork", "upstream")]
        [string]$Target,
        [switch]$WhatIf
    )

    if($WhatIf) {
        Write-Host "`$Target set to: $Target";
    }

    if($Target -eq "fork") {
        $path = "$global:DrivePath\git\hub\haplois\-dotnet\sdk"
    } elseif ($Target -eq "upstream") {
        $path = "$global:DrivePath\git\hub\dotnet\sdk";
    } else {
        $path = (Get-Location).Path
        
        if($WhatIf) {
            Write-Host "Auto sensing from: $path";
        }

        if ($path.ToLowerInvariant().Contains("$global:DrivePath\git\hub\dotnet\")) {
            $path = "$global:DrivePath\git\hub\dotnet\sdk";
        } else {
            $path = "$global:DrivePath\git\hub\haplois\-dotnet\sdk"
        }
    }

    if($WhatIf) {
        Write-Host "`& `"$($path)\eng\dogfood.ps1`"" -ForegroundColor Green
        # Write-Host "dotnet --info" -ForegroundColor Green
    } else {
        & "$($path)\eng\dogfood.ps1"
        # dotnet --info
    }
}

function Set-SdkBuild ([switch]$fork) 
{
    $path = (Get-Location).Path.ToLowerInvariant()
    if ($fork -or $path.Contains("$global:DrivePath\git\hub\haplois\-dotnet\sdk")) {
        $path = "$global:DrivePath\git\hub\haplois\-dotnet\sdk"
    } else {
        $path = "$global:DrivePath\git\hub\dotnet\sdk";
    }
    
    Write-Host "Setting DOTNET environemnt variables..." -ForegroundColor Green

    $env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
    $env:DOTNET_MULTILEVEL_LOOKUP=0

    $env:DOTNET_ROOT="$path\.dotnet"
    $env:DOTNET_MSBUILD_SDK_RESOLVER_CLI_DIR="$path\.dotnet"

    $env:PATH="$path\.dotnet;$($env:PATH)"
    $env:NUGET_PACKAGES="c:\Users\medenibaykal\.nuget\packages\"

    Write-Host "DOTNET_SKIP_FIRST_TIME_EXPERIENCE: " -NoNewline
    Write-Host "$($env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE)" -ForegroundColor Green
    
    Write-Host "DOTNET_MULTILEVEL_LOOKUP: " -NoNewline
    Write-Host "$($env:DOTNET_MULTILEVEL_LOOKUP)" -ForegroundColor Green
    
    Write-Host "DOTNET_ROOT: " -NoNewline
    Write-Host "$($env:DOTNET_ROOT)" -ForegroundColor Green
    
    Write-Host "DOTNET_MSBUILD_SDK_RESOLVER_CLI_DIR: " -NoNewline
    Write-Host "$($env:DOTNET_MSBUILD_SDK_RESOLVER_CLI_DIR)" -ForegroundColor Green

    Write-Host "NUGET_PACKAGES: " -NoNewline
    Write-Host "$($env:NUGET_PACKAGES)" -ForegroundColor Green

    Write-Host "PATH: " 
    Write-Host "$($env:PATH)" -ForegroundColor Green
}

function Clear-Folder ([switch]$Force, [switch]$WhatIf) 
{
    if(Test-Path .\artifacts\) {
        Stop-Dotnet
        tskill.exe "vstest.console*"
        Remove-Item .\artifacts\ -Recurse -Force
    }

    $addon = ""
    if($Force) { $addon += " -Force" }
    if($WhatIf) { $addon += " -WhatIf" }
    
    Invoke-Expression -Command "Get-ChildItem bin,obj,TestResults,artifacts -Recurse -Force -Directory | Remove-Item $addon -Recurse -Verbose"
    
    If(Test-Path .\tools) {
        Invoke-Expression -Command "Get-ChildItem tools -Force -Directory | Remove-Item $addon -Recurse -Verbose"
    }
    
    If(Test-Path .\packages) {
        Invoke-Expression -Command "Get-ChildItem packages -Force -Directory | Remove-Item $addon -Recurse -Verbose"
    }
    
    If(Test-Path .\artifacts) {
        Invoke-Expression -Command "Get-ChildItem artifacts -Force -Directory | Remove-Item $addon -Recurse -Verbose"
    }

    if(!$WhatIf) {
        git clean -xdf
    }
}

filter script:quoteStringWithSpecialChars 
{
    if ($_ -and ($_ -match '\s+|#|@|\$|;|,|''|\{|\}|\(|\)')) {
        $str = $_ -replace "'", "''"
        "'$str'"
    }
    else {
        $_
    }
}

function script:gitBranches($filter, $includeHEAD = $false, $prefix = '') 
{
    if ($filter -match "^(?<from>\S*\.{2,3})(?<to>.*)") {
        $prefix += $matches['from']
        $filter = $matches['to']
    }

    $branches = @(git branch --no-color | ForEach-Object { if (($_ -notmatch "^\* \(HEAD detached .+\)$") -and ($_ -match "^[\*\+]?\s*(?<ref>.*)")) { $matches['ref'] } }) +
                @(git branch --no-color -r | ForEach-Object { if ($_ -match "^  (?<ref>\S+)(?: -> .+)?") { $matches['ref'] } }) +
                @(if ($includeHEAD) { 'HEAD','FETCH_HEAD','ORIG_HEAD','MERGE_HEAD' })

    $branches |
        Where-Object { $_ -ne '(no branch)' -and $_ -like "$filter*" } |
        ForEach-Object { $prefix + $_ } |
        script:quoteStringWithSpecialChars
}

# Handles Remove-GitBranch -Name parameter auto-completion using the built-in mechanism for cmdlet parameters
Microsoft.PowerShell.Core\Register-ArgumentCompleter -CommandName Get-GitLog -ParameterName Branch -ScriptBlock {
    param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)

    gitBranches $WordToComplete $true
}

Microsoft.PowerShell.Core\Register-ArgumentCompleter -CommandName Import-GitRepo -ParameterName Branch -ScriptBlock {
    param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)

    gitBranches $WordToComplete $true
}

Set-Alias -Name l -Value Get-GitLog
Set-Alias -Name s -Value Get-GitStatus
Set-Alias -Name c -Value Import-GitRepo
Set-Alias -Name cdr -value Set-LocationToRepository
Set-Alias -Name cdi -value Set-LocationToIssue
Set-Alias -Name nuke -Value Clear-Folder

Export-ModuleMember -Function Test-GPG, Get-RepositoryPath, Set-LocationToRepository, `
                              Get-GitLog, Get-GitStatus, Import-GitRepo, `
                              Start-Dogfood, Set-SdkBuild, `
                              Clear-Folder `
                    -Alias l, s, c, cdr, cdi, nuke