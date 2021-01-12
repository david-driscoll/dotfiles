# Add Cmder modules directory to the autoload path.
$CmderModulePath = Join-path $PSScriptRoot "psmodules/"

if (-not $env:PSModulePath.Contains($CmderModulePath) ) {
    $env:PSModulePath = $env:PSModulePath.Insert(0, "$CmderModulePath$([System.IO.Path]::PathSeparator)")
}

if ([Environment]::OSVersion.VersionString -like "Microsoft Windows*") {
    if (-not ($ENV:APPDATA)) {
        $ENV:APPDATA = [Environment]::GetFolderPath('ApplicationData');
    }

    if (-not ($ENV:LOCALAPPDATA)) {
        $ENV:LOCALAPPDATA = [Environment]::GetFolderPath('LocalApplicationData');
    }
}

foreach ($x in Get-ChildItem $PSScriptRoot/profile.pwsh -Filter *.ps1) {
    # write-host write-host Sourcing $x
    . $x.FullName
    # Write-Host "Loading" $x.Name "took" $r.TotalMilliseconds"ms"
}

$ENV:STARSHIP_CONFIG = Join-Path $PSScriptRoot 'starship.toml';
if ($IsWindows) {
    $ENV:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User);
    $ENV:USER = $ENV:USERNAME;
}

starship init powershell     | Join-String { $_ -replace " ''\)$", " ' ')" } -Separator "`n" | Invoke-Expression
volta completions powershell | Join-String { $_ -replace " ''\)$", " ' ')" } -Separator "`n" | Invoke-Expression
gh completion -s powershell  | Join-String { $_ -replace " ''\)$", " ' ')" } -Separator "`n" | Invoke-Expression

$starshipPrompt = (Get-Command Prompt).ScriptBlock.ToString();
$starshipPrompt = $starshipPrompt + @'
    $title = $out[1].ToString()
    $space = $title.IndexOf('');
    $gitStop = $title.LastIndexOf('');
    $title = $title.Substring($space + 1, ($gitStop - $space)-1)
    $host.UI.RawUI.WindowTitle = $title -replace '\x1b\[[0-9;]*m', ''
'@;
$starshipPrompt = [Scriptblock]::Create($starshipPrompt);

function global:prompt {
    Invoke-Command -ScriptBlock $starshipPrompt;
}

$env:PYTHONIOENCODING = "utf-8"
iex "$(thefuck --alias)"

Import-Module ZLocation

Start-SshAgent -Quiet

# Doesn't look great in conenum
[PoshCode.Pansies.RgbColor]::ColorMode = [PoshCode.Pansies.ColorMode]::XTerm256;
