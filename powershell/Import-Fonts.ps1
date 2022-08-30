Set-StrictMode -Version Latest
[void] [System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")

$script:Path = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Source)
$script:FontsFolder = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::Fonts)
$script:TempFolder = Join-Path ([System.IO.Path]::GetTempPath()) -ChildPath ([System.Guid]::NewGuid())
$script:ZipPath = Join-Path $script:TempFolder -ChildPath "CascadiaCode.zip"
$script:FontPath = Join-Path $script:TempFolder -ChildPath "CascadiaCode"

function Save-Uri {
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

try {
    New-Item -Path $script:TempFolder -ItemType Directory | Out-Null
    Save-Uri -Uri "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/CascadiaCode.zip" -OutFile $script:ZipPath
    Expand-Archive -Path $script:ZipPath -DestinationPath $script:FontPath

    $script:InstalledFonts = (New-Object System.Drawing.Text.InstalledFontCollection).Families
    $script:FontInterop = (New-Object -ComObject Shell.Application).Namespace(0x14)

    Get-ChildItem $script:FontPath -Filter "*.otf" | ForEach-Object {
        $PrivateFontCollection = New-Object System.Drawing.Text.PrivateFontCollection
        $PrivateFontCollection.AddFontFile($_.FullName)
        $FontName = $PrivateFontCollection.Families[-1].Name

        if ( -not ($script:InstalledFonts -contains $FontName)) 
        {
            Write-Host "`e[1m`e[36m$($FontName)`e[0m`e[36m installing." -NoNewline
            $script:FontInterop.CopyHere($_.FullName)
            Write-Host "`e[2K`r" -NoNewline
            Write-Host "`e[1m`e[32m$($FontName)`e[0m`e[32m installed."
        }
        else {
            Write-Host "`e[1m`e[32m$($FontName)`e[0m`e[32m already installed."
        }
    }
}
finally {
    Remove-Item -Path $script:TempFolder -Recurse -Force
}