Set-StrictMode -Version Latest

New-Module -Name "Core" -ScriptBlock {
    function Get-CurrentRoot ($Path)
    {
        if ([string]::IsNullOrEmpty($Path)) 
        {
            $Path = $PSScriptRoot
        }

        $directoryPath = (Get-Item $Path).FullName

        $p = Get-Item $directoryPath | Select-Object -ExpandProperty Target
        if ([string]::IsNullOrEmpty($p)) 
        {
            $p = $directoryPath
        }

        $item = (Get-Item $p)
        if ($item.Parent) 
        {
            $item.Parent.FullName
        }
        else 
        {
            $item.FullName
        }
    }

    function Edit-Profile 
    {
        $path = Join-Path -Path (Get-CurrentRoot) -ChildPath "..\"
        vscode $path
    }

    function Remove-History
    {
        Remove-Item ((Get-PSReadlineOption).HistorySavePath) -Force
    }

    Export-ModuleMember -Function Get-CurrentRoot, Edit-Profile, Remove-History
} | Import-Module

New-Module -Name "Darc-Helper" -ScriptBlock {
    function Find-DarcAssembly ($DarcCommandPath) 
    {
        $DarcCommandFolder = [System.IO.Path]::GetDirectoryName($DarcCommandPath)
        $DarcAssemblyPath = (Get-ChildItem -Path $DarcCommandFolder -Name "Microsoft.DotNet.Darc.dll" -Recurse)

        if([string]::IsNullOrEmpty($DarcAssemblyPath)) 
        {
            return $null
        }

        return Join-Path -Path $DarcCommandFolder -ChildPath $DarcAssemblyPath
    }

    function Init-Completion
    {
        # This is not supported there yet.
        if ($PSVersionTable.PSEdition -ne "Core") 
        {
            return
        }

        $DarcCommand = Get-Command darc
        if (-not $DarcCommand) 
        {
            return "No darc"
        }

        $DarcAssemblyPath = Find-DarcAssembly -DarcCommandPath $DarcCommand.Source
        if (-not $DarcAssemblyPath) 
        {
            return "No darc asm"
        }

        $DarcCompletionSourceCode = Get-Content (Join-Path -Path (Get-CurrentRoot) -ChildPath "cmdlets\DarcCompletion.cs") -Raw
        Add-Type -TypeDefinition $DarcCompletionSourceCode `
                 -ReferencedAssemblies "System.Collections", `
                                       "System.Linq", `
                                       "System.ObjectModel", `
                                       "System.Runtime", `
                                       "Microsoft.CSharp"

        $script:DarcCompletionSource = [DarcCompletion]::new($DarcAssemblyPath)
        $script:IsCompletionReady = $true
    }

    function Get-DarcCompletionSource
    {
        return $script:DarcCompletionSource;
    }

    function Start-DarcCompletion($CommandName, $WordToComplete, $Position) 
    {
        if(-not $script:IsCompletionReady) 
        {
            Init-Completion
        }

        if(-not $script:DarcCompletionSource.CanComplete) 
        {
            return
        }

        return $script:DarcCompletionSource.Complete($CommandName, $WordToComplete, $Position)
    }

    Export-ModuleMember -Function Start-DarcCompletion, Get-DarcCompletionSource
} | Import-Module

$script:Path = Get-CurrentRoot
$global:DrivePath = (Get-CurrentRoot).Substring(0, 2).ToLowerInvariant()

Import-Module "$PSScriptRoot\ProcessUtilities.psm1"
Import-Module "$PSScriptRoot\Repositories.psm1"
Import-Module "$PSScriptRoot\Tools.psm1"
Import-Module "$PSScriptRoot\VS.psm1"


