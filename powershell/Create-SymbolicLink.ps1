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

