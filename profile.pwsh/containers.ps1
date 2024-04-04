Set-Alias -Name k -Value kubectl
Set-Alias -Name d -Value docker
New-Alias -Name tf -Value terraform.exe
New-Alias -Name pl -Value pulumi

Import-Module DockerCompletion
Import-Module PSKubectlCompletion
Import-Module TerraformCompletion