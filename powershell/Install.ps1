Set-StrictMode -Version Latest

$script:Path = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Source)

winget install Microsoft.WindowsTerminal.Preview
winget install vscode-insiders
winget install git.git
winget install Microsoft.PowerShell

& "$script:Path\Create-SymbolicLink.ps1"
& "$script:Path\Import-Fonts.ps1"
& "$script:Path\Init.ps1"