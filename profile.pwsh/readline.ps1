$PSReadLineOptions = @{
	EditMode                      = "Emacs"
	AddToHistoryHandler           = { return $true }
	CompletionQueryItems          = 200
	HistoryNoDuplicates           = $true
	HistorySaveStyle              = "SaveIncrementally"
	HistorySearchCursorMovesToEnd = $true
	PredictionSource              = "HistoryAndPlugin"
	PredictionViewStyle           = "ListView" # InlineView
	ShowToolTips                  = $true
	# Colors                        = @{
	# 	"Command" = "#8181f7"
	# }
}
Set-PSReadLineOption @PSReadLineOptions

Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete
# Search auto-completion from history
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
if ($IsMacOS -or $IsLinux) {
	# Set-PSReadLineKeyHandler -Key Escape -Function BackwardKillInput
}
if ($IsWindows) {
}