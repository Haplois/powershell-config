Set-StrictMode -Version Latest

$global:DrivePath = "c:"

$script:Path = [System.IO.Path]::GetDirectoryName($PSScriptRoot)

Import-Module "$PSScriptRoot\ProcessUtilities.psm1"
Import-Module "$PSScriptRoot\Repositories.psm1"
Import-Module "$PSScriptRoot\Tools.psm1"
Import-Module "$PSScriptRoot\VS.psm1"


