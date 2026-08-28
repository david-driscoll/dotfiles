$PSReadLineOptions = @{
	EditMode                      = "Emacs"
	AddToHistoryHandler           = { return $true }
	CompletionQueryItems          = 200
	HistoryNoDuplicates           = $true
	HistorySaveStyle              = "SaveIncrementally"
	HistorySearchCursorMovesToEnd = $true
	ShowToolTips                  = $true
	# Colors                        = @{
	# 	"Command" = "#8181f7"
	# }
}

# Prediction rendering requires a terminal with virtual-terminal support.
if ($Host.UI.PSObject.Properties['SupportsVirtualTerminal'] -and
    $Host.UI.SupportsVirtualTerminal -and
    -not [Console]::IsOutputRedirected) {
	$PSReadLineOptions.PredictionSource = "HistoryAndPlugin"
	$PSReadLineOptions.PredictionViewStyle = "ListView" # InlineView
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