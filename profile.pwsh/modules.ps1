Import-Module Pansies
Import-Module posh-git
Import-Module Terminal-Icons
Import-Module Microsoft.PowerShell.TextUtility
Import-Module npm-completion
Import-Module Microsoft.WinGet.Client

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

Set-Alias -Name vscode -Value (Get-Command code).Path;
Set-Alias -Name rcode -Value (Get-Command code).Path;
Set-Alias -Name code -Value (Get-Command code-insiders).Path;
Set-Alias -Name icode -Value (Get-Command code-insiders).Path;

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