$ENV:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User);
$ENV:UserName = [System.Environment]::UserName
$ENV:UserDomain = [System.Environment]::DomainName
$ENV:USER = $ENV:USERNAME;
if (-not ($ENV:APPDATA)) {
    $ENV:APPDATA = [Environment]::GetFolderPath('ApplicationData');
}

if (-not ($ENV:LOCALAPPDATA)) {
    $ENV:LOCALAPPDATA = [Environment]::GetFolderPath('LocalApplicationData');
}
$ChocolateyProfile = "$env:ChocolateyInstall/helpers/chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
    Update-SessionEnvironment
}

Import-Module WSLTabCompletion
Import-Module WslInterop

Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    [Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
    $Local:word = $wordToComplete.Replace('"', '""')
    $Local:ast = $commandAst.ToString().Replace('"', '""')
    winget complete --word="$Local:word" --commandline "$Local:ast" --position $cursorPosition | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}