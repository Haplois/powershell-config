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

$script:Path = Get-CurrentRoot
$global:DrivePath = (Get-CurrentRoot).Substring(0, 2).ToLowerInvariant()

Import-Module "$PSScriptRoot\ProcessUtilities.psm1"
Import-Module "$PSScriptRoot\Repositories.psm1"
Import-Module "$PSScriptRoot\Tools.psm1"
Import-Module "$PSScriptRoot\VS.psm1"


