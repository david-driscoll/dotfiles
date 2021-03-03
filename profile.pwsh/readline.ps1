
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
# Search auto-completion from history
Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

# Show auto-complete predictions from history
Set-PSReadLineOption -ShowToolTips
Set-PSReadLineOption -PredictionSource history