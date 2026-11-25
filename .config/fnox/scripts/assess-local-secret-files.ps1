<#
.SYNOPSIS
    Read-only heuristic assessment of common local credential-related files.

.DESCRIPTION
    Checks a bounded set of common credential/configuration paths for the current
    user's home directory, plus any paths supplied with -Path. It reads only
    regular files at those exact paths (no directory traversal or recursion).

    The report contains only the path, a presence/status value, and broad
    heuristic classifications.     File contents and detected values are never written, returned, or
    serialized.     Paths recognized as private keys, environment files, or encryption
    identities are skipped without reading their contents. Supply only
    non-key configuration files as explicit paths.
    Regular text files larger than MaxBytes are skipped.

    Findings are heuristic: references and auth-like settings can be false
    positives, and no detected indicator does not prove a file has no secret.
    The script does not migrate files, change permissions, create files, or
    modify the machine.

.PARAMETER Path
    Optional explicit file paths to add to the default candidate list. Paths
    are treated literally; wildcards and directories are not expanded or read.

.PARAMETER MaxBytes
    Maximum file size in bytes to inspect. Defaults to 1 MiB.

.PARAMETER Json
    Return the safe metadata report as JSON. No file contents or values are
    included.

.PARAMETER NoDefaults
    Check only the paths supplied with -Path. This is useful for safely testing
    the script with synthetic files.

.EXAMPLE
    pwsh -NoProfile -File ./assess-local-secret-files.ps1

.EXAMPLE
    pwsh -NoProfile -File ./assess-local-secret-files.ps1 -Path "$HOME/.config/tool/credentials" -Json

.OUTPUTS
    System.Management.Automation.PSCustomObject or a JSON string when -Json is
    specified. Each record contains Path, Status, and Classifications only.

.NOTES
    This is a best-effort local inventory aid, not a secret scanner or security
    guarantee. It does not recurse, follow detected symbolic links, or inspect
    files larger than MaxBytes.     It skips recognized environment-file, private-key, and age-identity paths.
    On macOS and Linux, it uses the standard stat utility to confirm that each
    target is a regular file before reading it.
    If that check is unavailable or inconclusive, the path is skipped.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string[]]$Path = @(),

    [Parameter()]
    [ValidateRange(1, 10485760)]
    [int]$MaxBytes = 1048576,

    [Parameter()]
    [switch]$Json,

    [Parameter()]
    [switch]$NoDefaults
)

$ErrorActionPreference = 'Stop'

$homeDirectory = [Environment]::GetFolderPath([Environment+SpecialFolder]::UserProfile)
$relativeCandidates = @(
    '.kube/config'
    '.npmrc'
    '.ssh/config'
    '.ssh/id_ed25519'
    '.ssh/id_ecdsa'
    '.ssh/id_rsa'
    '.config/fnox/age.key'
    '.config/fnox/age.txt'
    '.config/mise/age.key'
    '.config/mise/age.txt'
    '.config/sops/age/keys.txt'
    '.git-credentials'
    '.docker/config.json'
    '.aws/credentials'
    '.netrc'
    '.config/gh/hosts.yml'
)

$candidatePaths = [System.Collections.Generic.List[string]]::new()
if (-not $NoDefaults.IsPresent) {
    foreach ($relativePath in $relativeCandidates) {
        $candidatePaths.Add((Join-Path -Path $homeDirectory -ChildPath $relativePath))
    }
}
foreach ($explicitPath in $Path) {
    $candidatePaths.Add($explicitPath)
}

$pathComparer = [System.StringComparer]::Ordinal
if ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT) {
    $pathComparer = [System.StringComparer]::OrdinalIgnoreCase
}
$seenPaths = [System.Collections.Generic.HashSet[string]]::new($pathComparer)
$results = [System.Collections.Generic.List[object]]::new()

$referencePattern = '(?im)^\s*(?:(?:certificate-authority|client-certificate|client-key|auth-provider|tokenFile|exec|credential_process|web_identity_token_file|[A-Za-z0-9_.-]*(?:_FILE|_PATH))\s*[:=]\s*|identityfile\s+)\S+'
$embeddedAuthPatterns = @(
    '(?im)^\s*["'']?(?:token|password|passwd|secret|client[_-]?secret|client[_-]?key[_-]?data|client[_-]?certificate[_-]?data|private[_-]?key[_-]?data|api[_-]?key|access[_-]?key|private[_-]?key|authorization|auth)["'']?\s*[:=]\s*["'']?\S+'
    '(?im)["''][A-Za-z0-9_.-]*(?:_token|_password|_passwd|_secret|_api[_-]?key|_access[_-]?key|_private[_-]?key|_authorization|_credential|_auth(?:token)?)["'']\s*:\s*["'']?\S+'
    '(?im)^\s*[^#;\r\n]*\b[A-Za-z0-9_.-]*(?:_token|_password|_passwd|_secret|_api[_-]?key|_access[_-]?key|_private[_-]?key|_authorization|_credential|_auth(?:token)?)\s*=\s*\S+'
    '(?im)["'']auth["'']\s*:\s*["'']?\S+'
    '(?im)\b(?:password|passwd|token)\s+\S+'
    '(?im)https?://[^/\s:@]+:[^@\s/]+@'
    '(?im)^\s*(?:client-key-data|client-certificate-data|private-key-data)\s*:\s*\S+'
)

function Test-RegularFile {
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath,

        [Parameter(Mandatory)]
        [System.IO.FileSystemInfo]$Item
    )

    if (($Item.Attributes -band [System.IO.FileAttributes]::Directory) -or
        ($Item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -or
        ($Item.Attributes -band [System.IO.FileAttributes]::Device) -or
        $Item.LinkType) {
        return $false
    }

    if ($IsWindows) {
        return ($Item -is [System.IO.FileInfo])
    }

    $statCommand = Get-Command -Name stat -CommandType Application -ErrorAction SilentlyContinue
    if (-not $statCommand) {
        return $false
    }

    if ($IsMacOS) {
        $fileType = & $statCommand.Source -f '%HT' $LiteralPath 2>$null
    }
    else {
        $fileType = & $statCommand.Source -c '%F' -- $LiteralPath 2>$null
    }

    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    return ([string]$fileType).Trim() -in @('regular file', 'Regular File')
}

foreach ($candidatePath in $candidatePaths) {
    $content = $null
    try {
        $fullPath = [System.IO.Path]::GetFullPath($candidatePath)
    }
    catch {
        $results.Add([pscustomobject]@{
            Path = $candidatePath
            Status = 'InvalidPath'
            Classifications = @()
        })
        continue
    }

    if (-not $seenPaths.Add($fullPath)) {
        continue
    }

    if (-not (Test-Path -LiteralPath $fullPath -PathType Leaf)) {
        $status = if (Test-Path -LiteralPath $fullPath -PathType Container) {
            'SkippedDirectory'
        }
        else {
            'Missing'
        }
        $results.Add([pscustomobject]@{
            Path = $fullPath
            Status = $status
            Classifications = @()
        })
        continue
    }

    try {
        $fileItem = Get-Item -LiteralPath $fullPath -Force
    }
    catch {
        $results.Add([pscustomobject]@{
            Path = $fullPath
            Status = 'Unreadable'
            Classifications = @()
        })
        continue
    }

    if (-not (Test-RegularFile -LiteralPath $fullPath -Item $fileItem)) {
        $results.Add([pscustomobject]@{
            Path = $fullPath
            Status = 'SkippedNonRegularOrTypeUnknown'
            Classifications = @()
        })
        continue
    }

    $leafName = [System.IO.Path]::GetFileName($fullPath)
    if ($leafName -match '^(?:\.env(?:\..*)?|.*\.env|id_(?:rsa|dsa|ecdsa|ed25519)(?:[-_].*)?|age\.(?:key|txt)|keys\.txt)$' -or
        [System.IO.Path]::GetExtension($fullPath) -in @('.asc', '.jks', '.key', '.keystore', '.p12', '.p8', '.pem', '.pfx', '.ppk')) {
        $results.Add([pscustomobject]@{
            Path = $fullPath
            Status = 'SkippedSensitiveType'
            Classifications = @('sensitive-file-type')
        })
        continue
    }

    if ($fileItem.Length -gt $MaxBytes) {
        $results.Add([pscustomobject]@{
            Path = $fullPath
            Status = 'SkippedTooLarge'
            Classifications = @()
        })
        continue
    }

    try {
        $fileStream = [System.IO.File]::Open(
            $fullPath,
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete
        )
        try {
            $reader = [System.IO.StreamReader]::new($fileStream, [System.Text.Encoding]::UTF8, $true)
            try {
                $contentBuilder = [System.Text.StringBuilder]::new()
                $buffer = [char[]]::new([Math]::Min(8192, $MaxBytes))
                $remainingCharacters = $MaxBytes
                while ($remainingCharacters -gt 0) {
                    $readCount = $reader.ReadBlock(
                        $buffer,
                        0,
                        [Math]::Min($buffer.Length, $remainingCharacters)
                    )
                    if ($readCount -eq 0) {
                        break
                    }
                    [void]$contentBuilder.Append($buffer, 0, $readCount)
                    $remainingCharacters -= $readCount
                }
                $content = $contentBuilder.ToString()
            }
            finally {
                $reader.Dispose()
            }
        }
        finally {
            $fileStream.Dispose()
        }
    }
    catch {
        $results.Add([pscustomobject]@{
            Path = $fullPath
            Status = 'Unreadable'
            Classifications = @()
        })
        continue
    }

    $classifications = [System.Collections.Generic.List[string]]::new()
    if ([regex]::IsMatch($content, $referencePattern)) {
        $classifications.Add('credential-reference')
    }
    $hasEmbeddedAuthIndicator = $false
    foreach ($pattern in $embeddedAuthPatterns) {
        if ([regex]::IsMatch($content, $pattern)) {
            $hasEmbeddedAuthIndicator = $true
            break
        }
    }
    if ($hasEmbeddedAuthIndicator) {
        $classifications.Add('potential-embedded-auth-indicator')
    }
    if ($classifications.Count -eq 0) {
        $classifications.Add('no-known-indicators')
    }

    $results.Add([pscustomobject]@{
        Path = $fullPath
        Status = 'Present'
        Classifications = @($classifications)
    })

    $content = $null
}

if ($Json.IsPresent) {
    ConvertTo-Json -InputObject @($results) -Depth 4
}
else {
    @($results)
}
