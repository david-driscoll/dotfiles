mkdir "$ENV:USERPROFILE\dotfiles\.staged.psmodules\"
foreach ($module in gci "$ENV:USERPROFILE\dotfiles\psmodules\" -Directory) {
    Save-Module $module.Name "$ENV:USERPROFILE\dotfiles\.staged.psmodules\"
}

copy-item -Recurse "$ENV:USERPROFILE\dotfiles\.staged.psmodules\*" "$ENV:USERPROFILE\dotfiles\psmodules" -ErrorAction SilentlyContinue
rm -recurse "$ENV:USERPROFILE\dotfiles\.staged.psmodules\"