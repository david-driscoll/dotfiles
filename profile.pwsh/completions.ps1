function CheckAndRun($command) {
    if (-not (Get-Command $command.Split(' ')[0] -ErrorAction SilentlyContinue)) {
        return
    }
    (iex $command) | Out-String | Invoke-Expression
}

$oldPreference = $ErrorActionPreference
$ErrorActionPreference = "SilentlyContinue"

CheckAndRun "gh completion -s powershell"
CheckAndRun "op completion powershell"
CheckAndRun "mise activate pwsh"
CheckAndRun "kubectl completion powershell"
CheckAndRun "helm completion powershell"

$ErrorActionPreference = $oldPreference