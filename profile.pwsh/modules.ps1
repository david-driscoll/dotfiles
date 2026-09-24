. Invoke-DotfilesProfileStartupStep -Name 'Import Pansies' -ScriptBlock {
    Import-Module Pansies
}
. Invoke-DotfilesProfileStartupStep -Name 'Import posh-git' -ScriptBlock {
    Import-Module posh-git
}
. Invoke-DotfilesProfileStartupStep -Name 'Import Terminal-Icons' -ScriptBlock {
    # Terminal-Icons reads and then rewrites (non-atomically, via Export-Clixml)
    # every theme cache file under its storage path on EVERY import. Two pwsh
    # processes starting together can leave a half-written XML behind, and the
    # next import then fails with "Name cannot begin with the '<' character".
    # Serialize the import across processes, and drop any cache file that no
    # longer parses first -- the module regenerates it from its built-in themes.
    $terminalIconsMutex = [Threading.Mutex]::new($false, 'dotfiles-terminal-icons-import')
    $terminalIconsMutexHeld = $false
    try {
        try {
            $terminalIconsMutexHeld = $terminalIconsMutex.WaitOne([TimeSpan]::FromSeconds(10))
        }
        catch [Threading.AbandonedMutexException] {
            # A previous holder exited mid-import; we own the mutex now.
            $terminalIconsMutexHeld = $true
        }

        # Mirrors Terminal-Icons' own Get-ThemeStoragePath.
        $terminalIconsBasePath = if ($IsLinux -or $IsMacOS) {
            if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { [IO.Path]::Combine($HOME, '.local', 'share') }
        }
        elseif ($env:APPDATA) { $env:APPDATA }
        else { [Environment]::GetFolderPath('ApplicationData') }
        $terminalIconsStoragePath = [IO.Path]::Combine($terminalIconsBasePath, 'powershell', 'Community', 'Terminal-Icons')

        foreach ($terminalIconsCacheFile in Get-ChildItem -LiteralPath $terminalIconsStoragePath -Filter '*.xml' -ErrorAction Ignore) {
            try {
                $null = [xml](Get-Content -LiteralPath $terminalIconsCacheFile.FullName -Raw)
            }
            catch {
                Remove-Item -LiteralPath $terminalIconsCacheFile.FullName -Force -ErrorAction Ignore
            }
        }

        Import-Module Terminal-Icons
    }
    finally {
        if ($terminalIconsMutexHeld) {
            $terminalIconsMutex.ReleaseMutex()
        }
        $terminalIconsMutex.Dispose()
    }
}
. Invoke-DotfilesProfileStartupStep -Name 'Import Microsoft.PowerShell.TextUtility' -ScriptBlock {
    Import-Module Microsoft.PowerShell.TextUtility
}
. Invoke-DotfilesProfileStartupStep -Name 'Import npm-completion' -ScriptBlock {
    Import-Module npm-completion
}

function Get-ComputerName {
    if (Test-PsCore -and $PSVersionTable.Platform -ne 'Windows') {
        if ($env:NAME) {
            return $env:NAME
        }
        else {
            return (uname -n)
        }
    }
    return $env:COMPUTERNAME
}

function startCode {
    $codeCommand = Get-Command code;
    & $codeCommand ($args | ForEach-Object { if ($_.StartsWith('~')) { return (Resolve-Path $_).Path } return $_; })
}
function startCodeInsiders {
    $codeInsidersCommand = Get-Command code-insiders;
    & $codeInsidersCommand ($args | ForEach-Object { if ($_.StartsWith('~')) { return (Resolve-Path $_).Path } return $_; })
}
Set-Alias -Name vscode -Value startCode;
Set-Alias -Name rcode -Value startCode;
Set-Alias -Name code -Value startCodeInsiders;
Set-Alias -Name icode -Value startCodeInsiders;

Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    if ("$wordToComplete".StartsWith('dotnet nuke')) {
        dotnet nuke :complete "$wordToComplete".Substring(7) | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
    else {
        dotnet complete --position $cursorPosition "$wordToComplete" | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}

Register-ArgumentCompleter -Native -CommandName nuke -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    nuke :complete "$wordToComplete" | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

Register-ArgumentCompleter -Native -CommandName terraform -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    $env:COMP_LINE = $wordToComplete
    $env:COMP_POINT = $cursorPosition
    terraform.exe | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
    Remove-Item Env:\COMP_LINE
    Remove-Item Env:\COMP_POINT
}

function dotnet-tool-update {
    param (
        [string]$path = '.\.config\dotnet-tools.json'
    )
    if (Test-Path $path) {
        $data = (Get-Content -Raw $path | ConvertFrom-Json -AsHashtable).tools.Keys;
        foreach ($item in $data) {
            dotnet tool update $item;
        }
    }
}

Set-Alias -Name dtu -Value dotnet-tool-update

function Tag-Version {
    [CmdletBinding()]
    param (
        [switch] $beta
    )

    $version = gitversion | jq -r .MajorMinorPatch;
    if ($beta) {
        $version = gitversion | jq -r .SemVer;
    }
    git tag ("v{0}" -f $version)
}

function Ship-PublicApi {
    foreach ($unshipped in Get-ChildItem -Recurse PublicAPI.Unshipped.txt) {
        $shipped = "$($unshipped.Directory.FullName)\PublicAPI.Shipped.txt";

        $unshippedContent = Get-Content $unshipped -Raw;
        if ($unshippedContent -and $unshippedContent.Trim().Length -gt 0) {
            Add-Content $shipped $unshippedContent;
            Clear-Content $unshipped;
        }
    }
}

function Get-RandomPort($name, $from = 40000, $to = 49999) {
    [double]$code = [System.Math]::Abs(
        [System.BitConverter]::ToInt32(
            [System.Security.Cryptography.MD5]::Create().ComputeHash([System.Text.Encoding]::Default.GetBytes($name)),
            0
        )
    );

    $max = $code / [System.Int32]::MaxValue;
    $range = $to - $from;
    return [int]($range * $max + $from);

    # var code = Math.Abs(BitConverter.ToInt32(MD5.Create().ComputeHash(Encoding.Default.GetBytes($"{GitRemoteAutomation.RemoteName}@{assemblyName}")), 0));
    # var max = ((double)code) / int.MaxValue;
    # var range = endingPortRange - startingPortRange;
    # return (int)(range * max + startingPortRange);
}