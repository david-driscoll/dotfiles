$ENV:PATH = [System.Environment]::GetEnvironmentVariable("PATH", [System.EnvironmentVariableTarget]::User);
$ENV:USER = $ENV:USERNAME;
if (-not ($ENV:APPDATA)) {
    $ENV:APPDATA = [Environment]::GetFolderPath('ApplicationData');
}

if (-not ($ENV:LOCALAPPDATA)) {
    $ENV:LOCALAPPDATA = [Environment]::GetFolderPath('LocalApplicationData');
}