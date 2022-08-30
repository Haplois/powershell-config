Set-StrictMode -Version Latest

$script:Path = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Source)
$script:LocalApplicationData = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData)
$script:OhMyPosh = Join-Path -Path $script:LocalApplicationData -ChildPath "Programs\oh-my-posh\bin\oh-my-posh.exe"
$script:ProfileInit = Join-Path -Path $script:Path -ChildPath "config\Init-Profile.ps1"
$script:Themes = Join-Path -Path $script:Path -ChildPath "config\*.json"
$script:ProfileFolder = [System.IO.Path]::GetDirectoryName($PROFILE.CurrentUserAllHosts)

if (Test-Path $script:OhMyPosh)
{
    winget upgrade JanDeDobbeleer.OhMyPosh -s winget
}
else
{
    winget install JanDeDobbeleer.OhMyPosh -s winget
}

Install-Module -Name Terminal-Icons -Repository PSGallery -Force
Install-Module -Name PSReadLine -AllowPrerelease -Force

Copy-Item -Path $script:ProfileInit -Destination $PROFILE.CurrentUserAllHosts -Force
Copy-Item -Path $script:Themes -Destination $script:ProfileFolder -Force

. $PROFILE.CurrentUserAllHosts