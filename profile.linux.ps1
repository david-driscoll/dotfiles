if (grep microsoft /proc/version) {
    $ENV:DISPLAY = "$(cat /etc/resolv.conf | grep nameserver | awk '{print $2; exit;}'):0.0" #GWSL
    $ENV:PULSE_SERVER = "tcp:$(cat /etc/resolv.conf | grep nameserver | awk '{print $2; exit;}')" #GWSL
    $ENV:LIBGL_ALWAYS_INDIRECT = 1 #GWSL
    $ENV:WINDOWS_USER = $(/mnt/c/Windows/System32/cmd.exe /c 'echo %USERNAME%' | sed -e 's/\r//g') > /dev/null 2>&1
    $ENV:GDK_SCALE = 1 #GWSL
    $ENV:QT_SCALE_FACTOR = 1 #GWSL
    # Configure ssh forwarding
    $ENV:SSH_AUTH_SOCK = "$ENV:HOME / .ssh/agent.sock"
    # need `ps -ww` to get non-truncated command for matching
    # use square brackets to generate a regex match for the process we want but that doesn't match the grep command running it!
    if (Get-Process | where { -not $_.CommandLine.Contains("npiperelay.exe -ei -s //./pipe/openssh-ssh-agent") }) {
        bash ~/.wslrc # ensures socat get started
    }
}
