Invoke-DotfilesProfileStartupStep -Name 'Import DockerCompletion' -ScriptBlock {
    Import-Module DockerCompletion
}
Invoke-DotfilesProfileStartupStep -Name 'Import PSKubectlCompletion' -ScriptBlock {
    Import-Module PSKubectlCompletion
}
