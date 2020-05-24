# We do this for Powershell as Admin Sessions because CMDER_ROOT is not beng set.
if (! $ENV:CMDER_ROOT ) {
    $ENV:CMDER_ROOT = resolve-path( $PSScriptRoot )
}

# Remove trailing '\'
# $ENV:CMDER_ROOT = (($ENV:CMDER_ROOT).trimend("\/"))

# Add Cmder modules directory to the autoload path.
$CmderModulePath = Join-path $PSScriptRoot "psmodules/"

if (-not $env:PSModulePath.Contains($CmderModulePath) ) {
    $env:PSModulePath = $env:PSModulePath.Insert(0, "$CmderModulePath$([System.IO.Path]::PathSeparator)")
}

# Enhance Path
$env:Path = "$Env:CMDER_ROOT$([System.IO.Path]::DirectorySeparatorChar)bin$([System.IO.Path]::PathSeparator)$env:Path"

foreach ($x in Get-ChildItem $ENV:CMDER_ROOT/profile.pwsh -Filter *.ps1) {
    # write-host write-host Sourcing $x
    . $x.FullName
    # Write-Host "Loading" $x.Name "took" $r.TotalMilliseconds"ms"
}

Start-SshAgent -Quiet

# Doesn't look great in conenum
[PoshCode.Pansies.RgbColor]::ColorMode = [PoshCode.Pansies.ColorMode]::XTerm256;
