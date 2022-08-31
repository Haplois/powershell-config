Set-StrictMode -Version Latest

function Test-Symbol() 
{
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [string[]]
        $file
    )

    Write-Host "Total $($file.Length) files..."
    $file | ForEach-Object {
        Write-Host "Checking symbols for: " -NoNewline
        Write-Host $_ -ForegroundColor Green
        & "$global:DrivePath\git\dd\VS\src\tools\VerifyInsertion\Tools\symcheck\symchk.exe" /s SRV*http://msdl.microsoft.com/download/symbols $($_)
    }
}

function NuGet 
{
    $nugetExeFolder = "$global:DrivePath\Programs\dotnet\.tools\NuGet"
    $nugetExe = Join-Path -Path $nugetExeFolder -ChildPath "tools\NuGet.exe"

    if(-not (Test-Path $nugetExe)) {
        if(-not (Test-Path $nugetExeFolder)) {
            New-Item -Path $nugetExeFolder -ItemType Directory | Out-Null
        }

        $nugetPackage = Join-Path -Path $nugetExeFolder -ChildPath "NuGet.CommandLine.nupkg.zip"
        Save-Uri -Uri "https://www.nuget.org/api/v2/package/NuGet.CommandLine/5.8.0" -OutFile $nugetPackage
        Expand-Archive -Path $nugetPackage -DestinationPath $nugetExeFolder
        Remove-Item $nugetPackage
    }
    
    & $nugetExe $args
}

function VSWhere 
{
    $vswhereFolder = "$global:DrivePath\Programs\dotnet\.tools\vswhere"
    
    if(! (Test-Path $vswhereFolder)) {
        Update-VSWhere
    }

    & "$($vswhereFolder)\tools\vswhere.exe" $args
}

function Update-VSWhere 
{
    $toolsFolder = "$global:DrivePath\Programs\dotnet\.tools"
    $vswhereFolder = "$toolsFolder\vswhere"
    
    if(Test-Path $vswhereFolder) {
        Remove-Item $vswhereFolder -Force -Recurse
    }

    NuGet install vswhere -Prerelease -NonInteractive -OutputDirectory $toolsFolder
    # Rename-Item "$($vswhereFolder)*" "$vswhereFolder"
    Rename-Item -Path (Get-ChildItem "$($vswhereFolder)*")[0] -NewName "vswhere"
}

function Save-Uri 
{
    param (
        [string]
        $Uri,

        [string]
        $OutFile
    )
    
    try {
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest $Uri -OutFile $OutFile
    }
    finally {
        $ProgressPreference = 'Continue'
    }
}

function Symbol 
{
    $symbolExeFolder = Join-Path -Path $PSScriptRoot -ChildPath "tools\Symbol.App"
    $symbolExe = Join-Path -Path $symbolExeFolder -ChildPath "lib\net45\symbol.exe"

    if(-not (Test-Path $symbolExe)) {
        if(-not (Test-Path $symbolExeFolder)) {
            New-Item -Path $symbolExeFolder -ItemType Directory | Out-Null
        }

        $symbolPackagePath = Join-Path -Path $symbolExeFolder -ChildPath "Symbol.App.zip"
        Save-Uri -Uri "https://devdiv.artifacts.visualstudio.com/defaultcollection/_apis/symbol/client/exe" -OutFile $symbolPackagePath
        Expand-Archive -Path $symbolPackagePath -DestinationPath $symbolExeFolder
        Remove-Item $symbolPackagePath
    }
    
    & $symbolExe $args
}

function Start-VSCode 
{
    $vscoderoot = "$global:DrivePath\Users\medenibaykal\AppData\Local\Programs\Microsoft VS Code Insiders"

    if (!(Test-Path $vscoderoot)) 
    {
        $vscoderoot = "$global:DrivePath\Programs\vscode\app"
    }

    if ($args -eq $null -or $args.Count -eq 0) {
        (Start-Process -FilePath "$vscoderoot\bin\code-insiders.cmd" -WorkingDirectory . -LoadUserProfile -WindowStyle Hidden) | Out-Null
    }
    else {
        (Start-Process -FilePath "$vscoderoot\bin\code-insiders.cmd" -ArgumentList $args -WorkingDirectory . -LoadUserProfile -WindowStyle Hidden) | Out-Null
    }
}

function New-ItemInto 
{
    param ( [string]$Name )
    
    if (-not (Test-Path $Name)) 
    {
        New-Item -Path $Name -ItemType Directory -Force | Out-Null
    }

    Set-Location $Name
}

Set-Alias -Name vscode -Value Start-VSCode
Set-Alias -Name cdmk -Value New-ItemInto

Export-ModuleMember -Function Update-VSWhere, VSWhere, NuGet, `
                              Test-Symbol, Save-Uri, Symbol, Start-VSCode, `
                              New-ItemInto `
                    -Alias vscode, cdmk