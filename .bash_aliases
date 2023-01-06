alias cls=clear

# [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
if [ $WT_SESSION ]; then
    alias icode="\"$(which code-insiders)\""
    alias rcode="\"$(which code)\""
    alias vscode="\"$(which code)\""
    alias code="\"$(which code-insiders)\""
else
    alias icode=$(which code-insiders)
    alias rcode=$(which code)
    alias vscode=$(which code)
    alias code=$(which code-insiders)
fi
