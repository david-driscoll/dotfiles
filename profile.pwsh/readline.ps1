# Keep junk out of the history file. PSReadLine reads the whole file when the first
# prompt starts (and again for SaveIncrementally), so a few binary lines -- in 2026-11
# the file reached 5.2 GB from 14 of them -- freeze input in every new terminal.
# Skips very long input, control characters other than tab/newline, and U+FFFD
# (what undecodable bytes turn into).
$DotfilesMaxHistoryLineLength = 8192
$PSReadLineOptions = @{
	EditMode                      = "Windows"
	AddToHistoryHandler           = {
		param([string] $line)
		if ($line.Length -gt $DotfilesMaxHistoryLineLength -or
			$line -match '[\x00-\x08\x0B-\x1F\x7F�]') {
			return [Microsoft.PowerShell.AddToHistoryOption]::SkipAdding
		}
		return $true
	}.GetNewClosure()
	CompletionQueryItems          = 200
	HistoryNoDuplicates           = $true
	HistorySaveStyle              = "SaveIncrementally"
	HistorySearchCursorMovesToEnd = $true
	ShowToolTips                  = $true
	# Colors                        = @{
	# 	"Command" = "#8181f7"
	# }
}

# Warp has its own input editor and drives PSReadLine with Esc-prefixed chords: it writes
# "Esc 2" (bound to BackwardDeleteLine) in front of every command. Off Windows that only
# resolves as a chord in Emacs mode; Windows mode runs RevertLine for the Esc and then types
# the "2", so commands arrive as "2git status".
if (-not $IsWindows -and $env:TERM_PROGRAM -eq 'WarpTerminal') {
	$PSReadLineOptions.EditMode = "Emacs"
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

	# Windows mode leaves unbound what terminals here send for the native Option/Cmd editing keys.
	Set-PSReadLineKeyHandler -Chord Alt+b -Function BackwardWord             # Option+Left
	Set-PSReadLineKeyHandler -Chord Alt+f -Function NextWord                 # Option+Right
	Set-PSReadLineKeyHandler -Chord Alt+Backspace -Function BackwardKillWord # Option+Backspace
	Set-PSReadLineKeyHandler -Chord Alt+d -Function KillWord                 # Option+Delete
	Set-PSReadLineKeyHandler -Chord Ctrl+e -Function EndOfLine               # Cmd+Right
	Set-PSReadLineKeyHandler -Chord Ctrl+u -Function BackwardDeleteInput     # Cmd+Backspace
}
if ($IsWindows) {
}

Set-PSReadLineKeyHandler -Chord Ctrl+Backspace -Function BackwardKillWord
Set-PSReadLineKeyHandler -Chord Ctrl+LeftArrow -Function BackwardWord
Set-PSReadLineKeyHandler -Chord Ctrl+RightArrow -Function NextWord
Set-PSReadLineKeyHandler -Chord Ctrl+v, Shift+Insert -Function Paste
Set-PSReadLineKeyHandler -Chord Ctrl+Spacebar -Function MenuComplete
Set-PSReadLineKeyHandler -Chord Ctrl+Delete -Function KillWord
Set-PSReadLineKeyHandler -Chord "Ctrl+End" -Function ForwardDeleteInput
Set-PSReadLineKeyHandler -Chord Ctrl+H -Function BackwardDeleteChar
