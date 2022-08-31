Set-StrictMode -Version Latest

$script:Path = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Source)
$script:MyDocuments = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::MyDocuments)
$script:VaultPath = "$script:MyDocuments\WindowsPowerShell", "$script:MyDocuments\PowerShell"
$script:RealPath = Join-Path $script:Path -ChildPath .\profile

foreach($currentPath in $script:VaultPath) {
    if (Test-Path -Path $currentPath) {
        Write-Error "`"$currentPath`" already exist, delete it first."
        return
    }

    New-Item $currentPath -Value $script:RealPath -ItemType SymbolicLink
}

$script:CmdletsPath = Join-Path $script:Path -ChildPath .\cmdlets
$script:CmdletsTarget = Join-Path $script:RealPath -ChildPath .\plugins

if (Test-Path -Path $script:CmdletsTarget) {
    Write-Error "`"$script:CmdletsTarget`" already exist, delete it first."
    return
}

New-Item $script:CmdletsTarget -Value $script:CmdletsPath -ItemType SymbolicLink