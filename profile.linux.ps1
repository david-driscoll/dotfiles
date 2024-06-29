if (grep microsoft /proc/version) {
    $ENV:WINDOWS_USER = $(/mnt/c/Windows/System32/cmd.exe /c 'echo %USERNAME%' | sed -e 's/\r//g') > /dev/null 2>&1
    # Configure ssh forwarding
    $ENV:SSH_AUTH_SOCK = "$ENV:HOME/.1password/agent.sock"
    # need `ps -ww` to get non-truncated command for matching
    # use square brackets to generate a regex match for the process we want but that doesn't match the grep command running it!
    if (Get-Process | where { -not $_.CommandLine.Contains("npiperelay.exe -ei -s //./pipe/openssh-ssh-agent") }) {
        bash ~/.wslrc # ensures socat get started
    }
}
