$ENV:HOMEBREW_PREFIX = "/opt/homebrew";
$ENV:HOMEBREW_CELLAR = "/opt/homebrew/Cellar";
$ENV:HOMEBREW_REPOSITORY = "/opt/homebrew";
if ($ENV:PATH) {
    $ENV:PATH = "~/.jetbrains:$ENV:PATH";
}
if ($ENV:PATH) {
    $ENV:PATH = "~/.dotnet:$ENV:PATH";
    $ENV:PATH = "~/.dotnet/tools:$ENV:PATH";
}
if ($ENV:PATH) {
    $ENV:PATH = "/opt/homebrew/bin:/opt/homebrew/sbin:$ENV:PATH";
}
if ($ENV:MANPATH) {
    $ENV:MANPATH = "/opt/homebrew/share/man${ENV:MANPATH}:";
}
if ($ENV:INFOPATH) {
    $ENV:INFOPATH = "/opt/homebrew/share/info:${$ENV:INFOPATH}";
}

