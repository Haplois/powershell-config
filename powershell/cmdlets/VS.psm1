Set-StrictMode -Version Latest

$global:Dev16Root = "$global:DrivePath\programs\vs\app\dev16";
$global:Dev17Root = "$global:DrivePath\programs\vs\app\dev17";
$script:Path = [System.IO.Path]::GetDirectoryName($PSScriptRoot)

function Install-VS 
{
    # .\dev15.build-tools.exe --productId "Microsoft.VisualStudio.Product.BuildTools" --installWhileDownloading --config "$global:DrivePath\programs\vs\dev15.build-tools.vsconfig" --path cache="$global:DrivePath\programs\vs\cache\" --path shared="$global:DrivePath\programs\vs\shared\" --norestart --wait --passive
    Write-Host "Installing  `"Microsoft.VisualStudio.Product.BuildTools`"." -ForegroundColor White -BackgroundColor Green
    Start-Process -FilePath "$global:DrivePath\programs\vs\dev15.build-tools.exe" -ArgumentList "--productId", "`"Microsoft.VisualStudio.Product.Enterprise`"", "--path", "cache=`"$global:DrivePath\programs\vs\cache`"", "--path", "shared=`"$global:DrivePath\programs\vs\shared`"", "--focusedUi", "--installWhileDownloading", "--config", "`"$global:DrivePath\programs\vs\dev15.build-tools.vsconfig`"", "--norestart", "--wait", "--passive" -Wait -PassThru
  
    # .\dev16.release.exe --productId "Microsoft.VisualStudio.Product.Enterprise" --path cache="$global:DrivePath\programs\vs\cache" --path shared="$global:DrivePath\programs\vs\shared" --path install="$global:DrivePath\Programs\vs\app\dev16\enterprise" --focusedUi --installWhileDownloading --config "$global:DrivePath\programs\vs\dev16.release.vsconfig" --passive
    Write-Host "Installing  dev16.release.exe `"Microsoft.VisualStudio.Product.Enterprise`"." -ForegroundColor White -BackgroundColor Green
    Start-Process -FilePath "$global:DrivePath\programs\vs\dev16.release.exe" -ArgumentList "--productId", "`"Microsoft.VisualStudio.Product.Enterprise`"", "--path", "cache=`"$global:DrivePath\programs\vs\cache`"", "--path", "shared=`"$global:DrivePath\programs\vs\shared`"", "--path", "install=`"$global:DrivePath\Programs\vs\app\dev16\enterprise`"", "--focusedUi", "--installWhileDownloading", "--config", "`"$global:DrivePath\programs\vs\dev16.release.vsconfig`"", "--norestart", "--wait", "--passive" -Wait -PassThru
  
    # .\dev16.release.exe --productId "Microsoft.VisualStudio.Product.Enterprise" --path cache="$global:DrivePath\programs\vs\cache" --path shared="$global:DrivePath\programs\vs\shared" --path install="$global:DrivePath\Programs\vs\app\dev16\enterprise" --focusedUi --installWhileDownloading --config "$global:DrivePath\programs\vs\dev16.release.vsconfig" --passive
    Write-Host "Installing  dev17.main.exe `"Microsoft.VisualStudio.Product.Enterprise`"." -ForegroundColor White -BackgroundColor Green
    Start-Process -FilePath "$global:DrivePath\programs\vs\dev17.main.exe" -ArgumentList "--productId", "`"Microsoft.VisualStudio.Product.Enterprise`"", "--path", "cache=`"$global:DrivePath\programs\vs\cache`"", "--path", "shared=`"$global:DrivePath\programs\vs\shared`"", "--path", "install=`"$global:DrivePath\Programs\vs\app\dev17\main`"", "--focusedUi", "--installWhileDownloading", "--config", "`"$global:DrivePath\programs\vs\dev17.main.vsconfig`"", "--norestart", "--wait", "--passive" -Wait -PassThru
}

function Update-VS 
{
    if (-not (Get-IsAdmin -eq $false)) {
        Invoke-ElevatedCommand { 
            Update-VS
            Pause    
        }
        return
    }

    Push-Location
    $temp = [System.IO.Path]::GetTempFileName();
    Remove-Item $temp
    New-Item $temp -Type Directory | Out-Null
    Set-Location $temp

    try {
        $installer = (vswhere -latest -prerelease -products * -format value -property properties_setupEngineFilePath)
        $paths = (vswhere -all -prerelease -products * -format value -property installationPath) -split [Environment]::NewLine
        
        foreach ($item in $paths) {
            Write-Host "Updating $item..." -ForegroundColor White -BackgroundColor Green
            Start-Process -FilePath $installer -ArgumentList "update", "--installPath", "`"$item`"", "--passive", "--force", "--norestart", "--focusedUi" -Wait -PassThru
        }
    }
    finally {
        Pop-Location
        Remove-Item $temp -Force -Recurse
    }
}

function Start-Dotnet ([string[]]$Sdk, [string[]]$Runtime, [switch]$x86, [switch]$SystemWide, [switch]$LTS, [switch]$Unset) 
{
    $ROOT_DIR = ".\"
    $TOOLS_DIR = Join-Path $ROOT_DIR ".tools"
    $DOTNET_DIR = Join-Path $TOOLS_DIR ".dotnet"
    $DOTNET_X86_DIR = $DOTNET_DIR + "_x86"

    if($SystemWide -or (-not $Sdk -and -not $Runtime)) {
        $ROOT_DIR = "${env:ProgramFiles}"
        $TOOLS_DIR = Join-Path $ROOT_DIR "dotnet"
        $DOTNET_DIR = Join-Path $ROOT_DIR "dotnet"

        $DOTNET_X86_DIR = "${env:ProgramFiles(x86)}\dotnet"
    }

    if($LTS) {
        $ROOT_DIR = "$global:DrivePath\Programs\dotnet\"
        $TOOLS_DIR = $ROOT_DIR
        $DOTNET_DIR = Join-Path $ROOT_DIR ".dotnet-lts"
        $DOTNET_X86_DIR = Join-Path $ROOT_DIR ".dotnet-lts-x86"
    }

    if($Unset -and (Test-Path Alias:\dotnet)) {
        Remove-Item -Path Alias:/dotnet -Force
        Write-Host "Alias dotnet unset."

        if(Test-Path Alias:\dotnet-x86) {
            Remove-Item -Path Alias:/dotnet-x86 -Force
            Write-Host "Alias dotnet-x86 unset."
        }

        return
    }

    $dotnetInstallRemoteScript = "https://raw.githubusercontent.com/dotnet/cli/master/scripts/obtain/dotnet-install.ps1"
    $dotnetInstallScript = Join-Path $TOOLS_DIR "dotnet-install.ps1"

    if($Sdk -or $Runtime) {
        if (-not (Test-Path $TOOLS_DIR)) {
            New-Item $TOOLS_DIR -Type Directory | Out-Null
        }

        Save-Uri -Uri $dotnetInstallRemoteScript -OutFile $dotnetInstallScript
        if (-not (Test-Path $dotnetInstallScript)) {
            Write-Error "Failed to download dotnet install script."
            return
        }

        if($Sdk) {
            foreach ($v in $Sdk) {
                & $dotnetInstallScript -InstallDir "$DOTNET_DIR" -Version $v -Channel $v -Architecture x64 -NoPath
    
                if ($x86) {
                    & $dotnetInstallScript -InstallDir "$DOTNET_X86_DIR" -Version $v -Channel $v -Architecture x86 -NoPath
                }
            }
        }
    
        if($Runtime) {
            foreach ($v in $Runtime) {
                & $dotnetInstallScript -InstallDir "$DOTNET_DIR" -Runtime 'dotnet' -Version $v -Channel $v -Architecture x64 -NoPath
    
                if ($x86) {
                    & $dotnetInstallScript -InstallDir "$DOTNET_X86_DIR" -Runtime 'dotnet' -Version $v -Channel $v -Architecture x86 -NoPath
                }
            }
        }
    }

    [System.Environment]::SetEnvironmentVariable('DOTNET_MULTILEVEL_LOOKUP', "0", [System.EnvironmentVariableTarget]::Process)
    [System.Environment]::SetEnvironmentVariable('DOTNET_SKIP_FIRST_TIME_EXPERIENCE', "1", [System.EnvironmentVariableTarget]::Process)
    [System.Environment]::SetEnvironmentVariable('DOTNET_ROOT', "$DOTNET_DIR", [System.EnvironmentVariableTarget]::Process)
    [System.Environment]::SetEnvironmentVariable('DOTNET_ROOT(x86)', "$DOTNET_X86_DIR", [System.EnvironmentVariableTarget]::Process)
    [System.Environment]::SetEnvironmentVariable('DOTNET_MSBUILD_SDK_RESOLVER_CLI_DIR', "$DOTNET_DIR", [System.EnvironmentVariableTarget]::Process)
    
    "---- dotnet environment variables"
    Get-ChildItem "Env:\dotnet_*"

    if($x86) {
        "`n`n---- x86 dotnet"
        try {
            & "$DOTNET_X86_DIR\dotnet.exe" --info 2> $null
        } catch {}
    }
    
    "`n`n---- x64 dotnet"
    & "$DOTNET_DIR\dotnet.exe" --info

    Set-Alias -name dotnet -value "$DOTNET_DIR\dotnet.exe" -Scope Global -Force 
    if($x86) {
        Set-Alias -name dotnet-x86 -value "$DOTNET_X86_DIR\dotnet.exe" -Scope Global -Force 
    }
}

function Stop-Dotnet 
{
    taskkill /F /IM dotnet.exe /T
    taskkill /F /IM VSTest.Console.exe /T
    taskkill /F /IM msbuild.exe /T

    if(Test-Path Alias:\dotnet) {
        Remove-Item -Path Alias:/dotnet -Force
        Write-Host "Alias dotnet unset."
    }

    if(Test-Path Alias:\dotnet-x86) {
        Remove-Item -Path Alias:/dotnet-x86 -Force
        Write-Host "Alias dotnet-x86 unset."
    }

    [System.Environment]::SetEnvironmentVariable('DOTNET_MULTILEVEL_LOOKUP', [string]::Empty, [System.EnvironmentVariableTarget]::Process)
    [System.Environment]::SetEnvironmentVariable('DOTNET_SKIP_FIRST_TIME_EXPERIENCE', [string]::Empty, [System.EnvironmentVariableTarget]::Process)
    [System.Environment]::SetEnvironmentVariable('DOTNET_ROOT', [string]::Empty, [System.EnvironmentVariableTarget]::Process)
    [System.Environment]::SetEnvironmentVariable('DOTNET_ROOT(x86)', [string]::Empty, [System.EnvironmentVariableTarget]::Process)
    [System.Environment]::SetEnvironmentVariable('DOTNET_MSBUILD_SDK_RESOLVER_CLI_DIR', [string]::Empty, [System.EnvironmentVariableTarget]::Process)
}

Set-Alias -Name vs       -Value "$global:Dev17Root\enterprise\common7\ide\devenv.exe" 
Set-Alias -Name vs16     -Value "$global:Dev16Root\enterprise\common7\ide\devenv.exe"
Set-Alias -Name vsmain   -Value "$global:Dev17Root\main\common7\ide\devenv.exe" 

Set-Alias -Name csc      -Value "$global:Dev17Root\enterprise\MSBuild\Current\bin\Roslyn\csc.exe"
Set-Alias -Name cscmain  -Value "$global:Dev17Root\main\MSBuild\Current\bin\Roslyn\csc.exe"

Set-Alias -Name tc  -Value "$global:Dev17Root\enterprise\common7\ide\CommonExtensions\Microsoft\TestWindow\vstest.console.exe"
Set-Alias -Name tc16 -Value "$global:Dev16Root\main\common7\ide\CommonExtensions\Microsoft\TestWindow\vstest.console.exe" 
Set-Alias -Name tcmain  -Value "$global:Dev17Root\main\common7\ide\CommonExtensions\Microsoft\TestWindow\vstest.console.exe"
Set-Alias -Name tclocal  -Value "$global:DrivePath\git\hub\haplois\-microsoft\vstest\artifacts\Debug\net451\win7-x64\vstest.console.exe"

Set-Alias -Name msbuild -Value "$global:Dev17Root\enterprise\MSBuild\Current\Bin\msbuild.exe"
Set-Alias -Name msbuild64 -Value "$global:Dev17Root\enterprise\MSBuild\Current\Bin\amd64\msbuild.exe"
Set-Alias -Name msbuildmain -Value "$global:Dev17Root\main\MSBuild\Current\Bin\msbuild.exe"
Set-Alias -Name msbuild64main -Value "$global:Dev17Root\main\MSBuild\Current\Bin\amd64\msbuild.exe"

Set-Alias -Name ildasm -Value "${env:ProgramFiles(x86)}\Microsoft SDKs\Windows\v10.0A\bin\NETFX 4.8 Tools\IlDasm.exe"
Set-Alias -Name ilasm -Value "C:\Windows\Microsoft.NET\Framework\v4.0.30319\ilasm.exe"

Set-Alias -Name dotnet-lts -Value "$global:DrivePath\Programs\dotnet\.dotnet-lts\dotnet.exe"

Export-ModuleMember -Function Install-VS, Update-VS, Start-Dotnet, Stop-Dotnet `
                    -Alias vs, vs16, vsmain, `
                           csc, cscmain, `
                           tc, tc16, tcmain, tclocal, `
                           msbuild, msbuild64, `
                           msbuildmain, msbuild64main, `
                           ildasm, ilasm, `
                           dotnet-lts
                           