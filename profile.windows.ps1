Invoke-DotfilesProfileStartupStep -Name 'Initialize Windows environment' -ScriptBlock {
    $env:PATH = [Environment]::GetEnvironmentVariable('PATH', [EnvironmentVariableTarget]::User)
    $env:UserName = [Environment]::UserName
    $env:UserDomain = [Environment]::DomainName
    $env:USER = $env:USERNAME
    if (-not $env:APPDATA) {
        $env:APPDATA = [Environment]::GetFolderPath('ApplicationData')
    }
    if (-not $env:LOCALAPPDATA) {
        $env:LOCALAPPDATA = [Environment]::GetFolderPath('LocalApplicationData')
    }

    $chocolateyProfile = "$env:ChocolateyInstall/helpers/chocolateyProfile.psm1"
    if (Test-Path $chocolateyProfile) {
        Import-Module $chocolateyProfile
        Update-SessionEnvironment
    }
}

$miseDotnetRoot = Join-Path $env:LOCALAPPDATA 'mise\dotnet-root'
if (Test-Path -LiteralPath (Join-Path $miseDotnetRoot 'dotnet.exe')) {
    # mise verifies SDK installs with `dotnet.exe` resolved from PATH.
    $env:MISE_DOTNET_ROOT = $miseDotnetRoot
    $env:DOTNET_ROOT = $miseDotnetRoot
    $env:DOTNET_MULTILEVEL_LOOKUP = '0'
    $env:PATH = "$miseDotnetRoot$([IO.Path]::PathSeparator)$env:PATH"
}

if (Get-Module -ListAvailable -Name WSLTabCompletion) {
    Invoke-DotfilesProfileStartupStep -Name 'Import WSLTabCompletion' -ScriptBlock {
        Import-Module WSLTabCompletion
    }
}
if (Get-Module -ListAvailable -Name WslInterop) {
    Invoke-DotfilesProfileStartupStep -Name 'Import WslInterop' -ScriptBlock {
        Import-Module WslInterop
    }
}
if (Get-Module -ListAvailable -Name Microsoft.WinGet.Client) {
    Invoke-DotfilesProfileStartupStep -Name 'Import Microsoft.WinGet.Client' -ScriptBlock {
        Import-Module Microsoft.WinGet.Client
    }
}

if ($env:OS -eq 'Windows_NT') {
    Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [Text.Utf8Encoding]::new()
        $Local:word = $wordToComplete.Replace('"', '""')
        $Local:ast = $commandAst.ToString().Replace('"', '""')
        winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
            [Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
