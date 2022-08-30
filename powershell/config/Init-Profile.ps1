Set-StrictMode -Version Latest

$script:Path = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Source)
$script:LocalApplicationData = [Environment]::GetFolderPath([System.Environment+SpecialFolder]::LocalApplicationData)
$script:OhMyPosh = Join-Path -Path $script:LocalApplicationData -ChildPath "Programs\oh-my-posh\bin\oh-my-posh.exe"
$script:Theme = Join-Path -Path $script:Path -ChildPath "theme.json"

$script:InitBlock = (& $script:OhMyPosh init powershell --config $script:Theme --strict)

Invoke-Expression -Command ($script:InitBlock)

Import-Module -Name Terminal-Icons
if ($host.Name -eq 'ConsoleHost')
{
    if (-not (Get-Module PSReadLine))
    {
        Import-Module PSReadLine
    }

    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -EditMode Windows
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    
    if (-not (Test-Path Variable:\IsCoreCLR))
    {
        Set-PSReadLineKeyHandler -Key F7 `
                                -BriefDescription History `
                                -LongDescription 'Show command history' `
                                -ScriptBlock {
            $pattern = $null
            [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$pattern, [ref]$null)
            if ($pattern)
            {
                $pattern = [regex]::Escape($pattern)
            }
    
            $history = [System.Collections.ArrayList]@(
                $last = ''
                $lines = ''
                foreach ($line in [System.IO.File]::ReadLines((Get-PSReadLineOption).HistorySavePath))
                {
                    if ($line.EndsWith('`'))
                    {
                        $line = $line.Substring(0, $line.Length - 1)
                        $lines = if ($lines)
                        {
                            "$lines`n$line"
                        }
                        else
                        {
                            $line
                        }
                        continue
                    }
    
                    if ($lines)
                    {
                        $line = "$lines`n$line"
                        $lines = ''
                    }
    
                    if (($line -cne $last) -and (!$pattern -or ($line -match $pattern)))
                    {
                        $last = $line
                        $line
                    }
                }
            )
            $history.Reverse()
    
            $command = $history | Out-GridView -Title History -PassThru
            if ($command)
            {
                [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                [Microsoft.PowerShell.PSConsoleReadLine]::Insert(($command -join "`n"))
            }
        }
    }
}

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
        $Local:word = $wordToComplete.Replace('"', '""')
        $Local:ast = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
}

# PowerShell parameter completion shim for the dotnet CLI
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
     param($commandName, $wordToComplete, $cursorPosition)
         dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
         }
 }