#Region '.\_init.ps1' 0
using namespace ColorMine.ColorSpaces
using namespace PoshCode.Pansies
using namespace ColorMine.Palettes
using namespace PoshCode.Pansies.Palettes
using namespace System.Collections.Generic

# On first import, if HostPreference doesn't exist, set it and strongly type it
if(!(Test-Path Variable:HostPreference) -or $HostPreference -eq $null) {
    [System.Management.Automation.ActionPreference]$global:HostPreference = "Continue"
}

Set-Variable HostPreference -Description "Dictates the action taken when a host message is delivered" -Visibility Public -Scope Global

if(-not $IsLinux -and -not $IsMacOS) {
    [PoshCode.Pansies.Console.WindowsHelper]::EnableVirtualTerminalProcessing()
}

if(Get-Command Add-MetadataConverter -ErrorAction SilentlyContinue) {
    Add-MetadataConverter @{
        RgbColor = { [PoshCode.Pansies.RgbColor]$args[0] }
        [PoshCode.Pansies.RgbColor] = { "RgbColor '$_'" }
    }
}
#EndRegion '.\_init.ps1' 23
#Region '.\Private\ConvertToCssColor.ps1' 0
function ConvertToCssColor {
    [CmdletBinding()]
    param(
        [Parameter(ParameterSetName="PListColorDictionary", Mandatory, Position = 0)]
        [Dictionary[string,object]]$colors,

        [Parameter(ParameterSetName="ColorValue", Mandatory, Position = 0)]
        [string]$color
    )
    end {
        if($PSCmdlet.ParameterSetName -eq "PListColorDictionary") {
            [int]$r = 255 * $colors["Red Component"]
            [int]$g = 255 * $colors["Green Component"]
            [int]$b = 255 * $colors["Blue Component"]
            [PoshCode.Pansies.RgbColor]::new($r, $g, $b).ToString()
        }
        if($PSCmdlet.ParameterSetName -eq "ColorValue") {
            [PoshCode.Pansies.RgbColor]::new($color).ToString()
        }
    }
}
#EndRegion '.\Private\ConvertToCssColor.ps1'
#Region '.\Private\ExportTheme.ps1' 0
function ExportTheme {
    <#
        .SYNOPSIS
            Imports themes by name
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The name of the theme
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ValueFromPipeline, Position = 1)]
        $InputObject,

        [switch]$Force,

        [switch]$Update,

        [switch]$PassThru,

        [ValidateSet("User", "Machine")]
        [string]$Scope = "User"
    )
    process {
        $NativeThemePath = Join-Path $(Get-ConfigurationPath -Scope $Scope) "$Name.theme.psd1"

        if(Test-Path -LiteralPath $NativeThemePath) {
            if($Update) {
                Write-Verbose "Updating $NativeThemePath"
                $Theme = Import-Metadata $NativeThemePath -ErrorAction Stop
                Update-Object -InputObject $Theme -UpdateObject $InputObject | Export-Metadata $NativeThemePath
            } elseif($Force -or $PSCmdlet.ShouldContinue("Overwrite $($NativeThemePath)?", "$Name Theme exists")) {
                Write-Verbose "Exporting to $NativeThemePath"
                $InputObject | Export-Metadata $NativeThemePath
            }
        } else {
            Write-Verbose "Exporting to $NativeThemePath"
            $InputObject | Export-Metadata $NativeThemePath
        }

        if($PassThru) {
            $InputObject | Add-Member NoteProperty Name $Name -Passthru |
                           Add-Member NoteProperty PSPath $NativeThemePath -Passthru
        }
    }
}
#EndRegion '.\Private\ExportTheme.ps1'
#Region '.\Private\FindVSCodeTheme.ps1' 0
function FindVsCodeTheme {
    [CmdletBinding()]
    param($Name)

    $VSCodeExtensions = @(
        # VS Code themes are in one of two places: in the app, or in your profile folder:
        Convert-Path "~\.vscode*\extensions\"
        # If `code` is in your path, we can guess where that is...
        Get-Command Code-Insiders, Code -ErrorAction Ignore |
            Split-Path | Split-Path | Join-Path -ChildPath "resources\app\extensions\"
    )
    $Warnings = @()

    $Themes = @(
        # If they passed a file path that exists, use just that one file
        if ($Specific = Test-Path -LiteralPath $Name) {
            $File = Convert-Path $Name
            $(
                if ($File.EndsWith(".json")) {
                    try {
                        # Write-Debug "Parsing json file: $File"
                        ConvertFrom-Json (Get-Content -Path $File -Raw -Encoding utf8) -ErrorAction SilentlyContinue
                    } catch {
                        Write-Error "Couldn't parse '$File'. $(
                        if($PSVersionTable.PSVersion.Major -lt 6) {
                            'You could try again with PowerShell Core, the JSON parser there works much better!'
                        })"
                    }
                } else {
                    # Write-Debug "Parsing PList file: $File"
                    Import-PList -Path $File
                }
            ) | Select-Object @{ Name = "Name"
                                 Expr = {
                                    if ($_.name) {
                                        $_.name
                                    } else {
                                        [IO.Path]::GetFileNameWithoutExtension($File)
                                    }
                                }
                           }, @{ Name = "Path"
                                 Expr = {$File}
                           }
        } else {
            $VSCodeExtensions  = $VSCodeExtensions | Join-Path -ChildPath "\*\package.json" -Resolve
            foreach ($File in $VSCodeExtensions) {
                # Write-Debug "Considering VSCode Extention $([IO.Path]::GetFileName([IO.Path]::GetDirectoryName($File)))"
                $JSON = Get-Content -Path $File -Raw -Encoding utf8
                try {
                    $Extension = ConvertFrom-Json $JSON -ErrorAction Stop
                    # if ($Extension.contributes.themes) {
                    #     Write-Debug "Found $($Extension.contributes.themes.Count) themes"
                    # }
                    $Extension.contributes.themes |
                        Select-Object @{Name="Name" ; Expr={$_.label}},
                                      @{Name="Style"; Expr={$_.uiTheme}},
                                      @{Name="Path" ; Expr={Join-Path (Split-Path $File) $_.path -resolve}}
                } catch {
                    $Warning = "Couldn't parse some VSCode extensions."
                }
            }
        }
    )
    if($Themes.Count -eq 0) {
        throw "Could not find any VSCode themes. Please use a full path."
    }

    if($Specific -and $Themes.Count -eq 1) {
        $Themes
    }

    # Make sure we're comparing the name to a name
    $Name = [IO.Path]::GetFileName(($Name -replace "\.json$|\.tmtheme$"))
    Write-Verbose "Testing theme names for '$Name'"

    # increasingly fuzzy search: (eq -> like -> match)
    if(!($Theme = $Themes.Where{$_.name -eq $Name})) {
        if (!($Theme = $Themes.Where{$_.name -like $Name})) {
            if (!($Theme = $Themes.Where{$_.name -like "*$Name*"})) {
                foreach($Warning in $Warnings) {
                    Write-Warning $Warning
                }
                Write-Error "Couldn't find the theme '$Name', please try another: $(($Themes.name | Select-Object -Unique) -join ', ')"
            }
        }
    }
    if(@($Theme).Count -gt 1) {
        $Dupes = $(if(@($Theme.Name | Get-Unique).Count -gt 1) {$Theme.Name} else {$Theme.Path}) -join ", "
        Write-Warning "Found more than one theme for '$Name'. Using '$(@($Theme)[0].Path)', but you could try again for one of: $Dupes)"
    }
    @($Theme)[0]
}
#EndRegion '.\Private\FindVSCodeTheme.ps1'
#Region '.\Private\GetColorProperty.ps1' 0
function GetColorProperty{
    <#
        .SYNOPSIS
            Search the colors for a matching theme color name and returns the foreground
    #>
    param(
        # The array of colors
        [Array]$colors,

        # An array of (partial) scope names in priority order
        # The foreground color of the first matching scope in the tokens will be returned
        [string[]]$name
    )
    # Since we loaded the themes in order of prescedence, we take the first match that has a foreground color
    foreach ($pattern in $name) {
        # Normalize color
        if($foreground = @($colors.$pattern).Where{$_}[0]) {
            ConvertToCssColor $foreground
            return
        }
    }
}
#EndRegion '.\Private\GetColorProperty.ps1'
#Region '.\Private\GetColorScopeForeground.ps1' 0
function GetColorScopeForeground {
    <#
        .SYNOPSIS
            Search the tokens for a scope name with a foreground color
    #>
    param(
        # The array of tokens
        [Array]$tokens,

        # An array of (partial) scope names in priority order
        # The foreground color of the first matching scope in the tokens will be returned
        [string[]]$name
    )
    # Since we loaded the themes in order of prescedence, we take the first match that has a foreground color
    foreach ($pattern in $name) {
        foreach ($token in $tokens) {
            if (($token.scope -split "\s*,\s*" -match $pattern) -and $token.settings.foreground) {
                ConvertToCssColor $token.settings.foreground
                return
            }
        }
    }
}
#EndRegion '.\Private\GetColorScopeForeground.ps1'
#Region '.\Private\ImportJsonIncludeLast.ps1' 0
function ImportJsonIncludeLast {
    <#
        .SYNOPSIS
            Import VSCode json themes, including any included themes
    #>
    [CmdletBinding()]
    param([string[]]$Path)

    # take the first
    $themeFile, $Path = $Path
    $theme = Get-Content $themeFile | ConvertFrom-Json

    # Output all the colors or token colors
    if ($theme.colors) {
        $theme.colors
    }
    if ($theme.tokenColors) {
        $theme.tokenColors
    }

    # Recurse includes
    if ($theme.include) {
        $Path += $themeFile | Split-Path | Join-Path -Child $theme.include | convert-path
    }
    if ($Path) {
        ImportJsonIncludeLast $Path
    }
}
#EndRegion '.\Private\ImportJsonIncludeLast.ps1'
#Region '.\Private\ImportTheme.ps1' 0
function ImportTheme {
    <#
        .SYNOPSIS
            Imports themes by name
    #>
    [CmdletBinding()]
    param(
        # The name of the theme
        [Parameter(Position=0)]
        [string]$Name
    )

    $FileName = $Name -replace "((\.theme)?\.psd1)?$" -replace '$', ".theme.psd1"

    $Path = if (!(Test-Path -LiteralPath $FileName)) {
        Get-Theme $Name | Select-Object -First 1 -ExpandProperty PSPath
    } else {
        Convert-Path $FileName
    }
    if(!$Path) {
        $Themes = @(Get-Theme "$Name*")
        if($Themes.Count -gt 1) {
            Write-Warning "No exact match for $Name. Using $($Themes[0]), but also found $($Themes[1..$($Themes.Count-1)] -join ', ')"
            $Path = $Themes[0].PSPath
        } elseif($Themes) {
            Write-Warning "No exact match for $Name. Using $($Themes[0])"
            $Path = $Themes[0].PSPath
        } else {
            $Themes = @(Get-Theme "*$Name*")
            if($Themes.Count -gt 1) {
                Write-Warning "No exact match for $Name. Using $($Themes[0]), but also found $($Themes[1..$($Themes.Count-1)] -join ', ')"
                $Path = $Themes[0].PSPath
            } elseif($Themes) {
                Write-Warning "No exact match for $Name. Using $($Themes[0])"
                $Path = $Themes[0].PSPath
            }
        }
        if(!$Path) {
            Write-Error "No theme '$Name' found. Try Get-Theme to see available themes."
            return
        }
    }

    Write-Verbose "Importing $Name theme from $Path"
    $Theme = Import-Metadata $Path -ErrorAction Stop

    # Cast the ConsoleColors here
    if($Theme['ConsoleColors']) {
        $Theme['ConsoleColors'] = $Theme['ConsoleColors'].ForEach([RgbColor])
    }
    # Convert colors to escape sequences for PSReadline.Colors
    if ($Colors = $Theme.PSReadline.Colors) {
        foreach ($color in @($Colors.Keys)) {
            # If it doesn't start with ESC
            if ($Colors[$color] -notmatch "^$([char]27)") {
                try {
                    # Use the RGBColor
                    $Colors[$color] = ([RgbColor]$Colors[$color]).ToVtEscapeSequence() <# |
                        Add-Member -MemberType NoteProperty -Name Color -Value ([RgbColor]$Colors[$color]) -PassThru #>
                } catch {
                    Write-Warning "Skipped 'PSReadLine.$color', because '$($Colors[$color])' is neither a color nor an escape sequence"
                    $null = $Colors.Remove($color)
                }
            }
        }
        $Theme['PSReadline']['Colors'] = $Colors
    }

    $Theme
}
#EndRegion '.\Private\ImportTheme.ps1'
#Region '.\Private\ShowPreview.ps1' 0
function ShowPreview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        $Palette,

        [Parameter(Position = 1)]
        $Syntax,

        $Name,

        [Switch]$Tiny,

        [Switch]$MoreText,

        [Switch]$NoCodeSample
    )
    if($null -eq $Syntax) {
        $Syntax  = Get-PSReadLineOption | Select-Object -Property @(
                @{Name = "ContinuationPrompt"; Expression = { $_.ContinuationPromptColor }}
                @{Name = "Parameter"; Expression = { $_.ParameterColor }}
                @{Name = "Member"; Expression = { $_.MemberColor }}
                @{Name = "Command"; Expression = { $_.CommandColor }}
                @{Name = "Operator"; Expression = { $_.OperatorColor }}
                @{Name = "Emphasis"; Expression = { $_.EmphasisColor }}
                @{Name = "Selection"; Expression = { $_.SelectionColor }}
                @{Name = "Variable"; Expression = { $_.VariableColor }}
                @{Name = "Type"; Expression = { $_.TypeColor }}
                @{Name = "Keyword"; Expression = { $_.KeywordColor }}
                @{Name = "String"; Expression = { $_.StringColor }}
                @{Name = "Error"; Expression = { $_.ErrorColor }}
                @{Name = "Number"; Expression = { $_.NumberColor }}
                @{Name = "Default"; Expression = { $_.DefaultTokenColor }}
                @{Name = "Comment"; Expression = { $_.CommentColor }}
            )
    }
    $e = [char]27

    -join $(
        "$($Name)`n"
        if($Palette) {
            if($Palette.Count -lt 16) {
                throw "Invalid theme: missing ConsoleColors (there should be 16, but are only $($Palette.Count))"
            }

            if (!$Tiny) {
                $ansi = 30
                $bold = $false
                "             Black   Red     Green   Yellow  Blue    Magenta Cyan    White   Gray    Dark Gray `n"
                "       49m     40m     41m     42m     43m     44m     45m     46m     47m     100m    107m    `n"
                "  39m"

                foreach($fg in @($null) + $Palette[0, 8, 4, 12, 2, 10, 6, 14, 1, 9, 5, 13, 3, 11, 7, 15]) {
                    if($fg) {
                        "$(if($bold){"1;"}else{"  "})$($ansi)m"
                        $ansi += $bold
                        $bold = !$bold
                    }
                    foreach($bg in @($null) + $Palette[0, 4, 2, 6, 1, 5, 3, 15, 7, 8]) {
                        $(if($null -ne $bg) { $bg.ToVtEscapeSequence($true) })
                        $(if($null -ne $fg) { $fg.ToVtEscapeSequence() })
                        "  gYw  $([char]27)[0m "
                    }
                    "`n"
                }
                "`n"
            }

            0..7 | ForEach-Object {
                $Dark = $Palette[$_]
                $Lite = $Palette[($_ + 8)]

                New-Text (" $([ConsoleColor]$_)".PadRight(12) + " $Dark ") -Fore (Get-Complement $Dark -Force) -Back $Dark -LeaveColor
                New-Text (" $([ConsoleColor]$_+8)".PadRight(9) + " $Lite ") -Fore (Get-Complement $Lite -Force) -Back $Lite
                "`n"
            }
        }

        if($Syntax -and !$NoCodeSample) {
            "$e[8A$e[45G$($Syntax.Keyword)function $($Syntax.Default)Test-Syntax $($Syntax.Default){"
            "$e[B$e[45G    $($Syntax.Comment)# Demo Syntax Highlighting"
            "$e[B$e[45G    $($Syntax.Default)[$($Syntax.Type)CmdletBinding$($Syntax.Default)()]"
            "$e[B$e[45G    $($Syntax.Keyword)param$($Syntax.Default)( [$($Syntax.Type)IO.FileInfo$($Syntax.Default)]$($Syntax.Variable)`$Path $($Syntax.Default))"
            "$e[B"
            "$e[B$e[45G    $($Syntax.Command)Write-Verbose $($Syntax.String)`"Testing in $($Syntax.Variable)`$($($Syntax.Command)Split-Path $($Syntax.Variable)`$PSScriptRoot $($Syntax.Parameter)-Leaf$($Syntax.Variable))$($Syntax.String)`" $($Syntax.Parameter)-Verbose"
            "$e[B$e[45G    $($Syntax.Variable)`$Env:PSModulePath $($Syntax.Operator)-split $($Syntax.String)';' $($Syntax.Operator)-notcontains $($Syntax.Variable)`$Path$($Syntax.Default).$($Syntax.Member)FullName"
            "$e[B$e[45G$($Syntax.Default)}$e[39m$e[B"
        }

        if($Palette -and $MoreText) {
            0, 8, 4, 12, 2, 10, 6, 14, 1, 9, 5, 13, 3, 11, 7, 15 | ForEach-Object {
                $Color = $Palette[$_]
                New-Text " This is a test " -Back Black -Fore $Color -LeaveColor
                New-Text " showing more " -Back DarkGray -Fore $Color -LeaveColor
                New-Text " sample text on " -Back Gray -Fore $Color -LeaveColor
                New-Text " common backgrounds: " -Back White -Fore $Color -LeaveColor
                New-Text " $Color $([ConsoleColor]$_) ".PadRight(22) -Fore $(if($_ -le 8 -and $_ -ne 7){"White"}else{"Black"}) -Back $Color
                "`n"
            }
            "`n"
        }
    )
}
#EndRegion '.\Private\ShowPreview.ps1'
#Region '.\Public\Convert-ConsolePalette.ps1' 0
function Convert-ConsolePalette {
    # .EXTERNALHELP Pansies-help.xml
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact="Medium", DefaultParameterSetName = "Dark")]
    param(
        # How much to shift the dark colors. Positive values make the colors brighter, negative values make them darker
        [Parameter(Mandatory, ParameterSetName = "Dark", Position = 0)]
        [int]$DarkShift,

        # How much to shift the bright colors. Positive values make the colors brighter, negative values make them darker
        [Parameter(Mandatory, ParameterSetName = "Bright")]
        [int]$BrightShift,

        # By default, the colors are modified in-place. If copy is set:
        # - the dark colors start with the value of the bright colors
        # - the light colors start at the value of the dark colors
        [switch]$Copy
    )
    $Palette = Get-ConsolePalette
    for($i=0;$i -lt 8; $i++){
        $Dark  = $Palette[$i].ToHunterLab()
        $Light = $Palette[$i+8].ToHunterLab()

        if ($BrightShift) {
            if ($Copy) {
                $Light = $Dark.ToHunterLab()
            }
            $Light.L  += $BrightShift
        }

        if ($DarkShift) {
            if ($Copy) {
                $Dark  = $Light.ToHunterLab()
            }
            $Dark.L   += $DarkShift
        }

        $Palette[$i]   = [PoshCode.Pansies.RgbColor]$Dark.ToRgb()
        $Palette[$i+8] = [PoshCode.Pansies.RgbColor]$Light.ToRgb()
    }

    ShowPreview $Palette -Tiny

    if($PSCmdlet.ShouldProcess("Save Theme")) {
        Set-ConsolePalette $Palette
    }
}
#EndRegion '.\Public\Convert-ConsolePalette.ps1'
#Region '.\Public\ConvertFrom-iTermColors.ps1' 0
function ConvertFrom-iTermColors {
    # .EXTERNALHELP Pansies-help.xml
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The name of (or full path to) an XML PList itermcolors scheme
        # If you provide just a name, will search for an .itermcolors file in the current folder and the theme
        [Alias("PSPath", "Name")]
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Theme,

        [switch]$Force,

        [switch]$Update,

        [switch]$Passthru,

        [ValidateSet("User", "Machine")]
        [string]$Scope = "User"
    )

    begin {
        # In Windows Color Table order
        $PListColorNames = @(
            "Ansi 0 Color"   # DARK_BLACK
            "Ansi 4 Color"   # DARK_BLUE
            "Ansi 2 Color"   # DARK_GREEN
            "Ansi 6 Color"   # DARK_CYAN
            "Ansi 1 Color"   # DARK_RED
            "Ansi 5 Color"   # DARK_MAGENTA
            "Ansi 3 Color"   # DARK_YELLOW
            "Ansi 7 Color"   # DARK_WHITE
            "Ansi 8 Color"   # BRIGHT_BLACK
            "Ansi 12 Color"  # BRIGHT_BLUE
            "Ansi 10 Color"  # BRIGHT_GREEN
            "Ansi 14 Color"  # BRIGHT_CYAN
            "Ansi 9 Color"   # BRIGHT_RED
            "Ansi 13 Color"  # BRIGHT_MAGENTA
            "Ansi 11 Color"  # BRIGHT_YELLOW
            "Ansi 15 Color"  # BRIGHT_WHITE
        )
    }

    process {
        if (!(Test-Path $Theme)) {
            throw [System.IO.FileNotFoundException]::new("Palette file not found", $Theme)
        }

        if (!($pList = Import-PList $Theme)) {
            return
        }

        $ThemeOutput = @{
            Name = [IO.Path]::GetFileNameWithoutExtension($Theme)
            ConsoleColors = @(
                foreach($color in $PListColorNames) {
                    if(!$pList[$color]) {
                        Wait-Debugger
                        Write-Warning "Missing color $color"
                        $null
                    } else {
                        ConvertToCssColor $pList[$color]
                    }
                }
            )
        }
        if ($pList.ContainsKey("Foreground Color") -and $pList.ContainsKey("Background Color")) {
            $ThemeOutput.ConsoleForeground = ConvertToCssColor $pList["Foreground Color"]
            $ThemeOutput.ConsoleBackground = ConvertToCssColor $pList["Background Color"]
        }
        if ($pList.ContainsKey("Bold Color")) {
            if (!$ThemeOutput['PSReadLine']) {
                $ThemeOutput['PSReadLine'] = @{}
            }
            if (!$ThemeOutput['PSReadLine']['Colors']) {
                $ThemeOutput['PSReadLine']['Colors'] = @{}
            }
            $ThemeOutput['PSReadLine']['Colors']['Emphasis'] = ConvertToCssColor $pList["Bold Color"]
        }
        if ($pList.ContainsKey("Selection Color")) {
            if (!$ThemeOutput['PSReadLine']) {
                $ThemeOutput['PSReadLine'] = @{}
            }
            if (!$ThemeOutput['PSReadLine']['Colors']) {
                $ThemeOutput['PSReadLine']['Colors'] = @{}
            }
            $ThemeOutput['PSReadLine']['Colors']['Selection'] = ConvertToCssColor $pList["Selection Color"]
        }
        if(!($Name = $pList["name"])) {
            $Name = ([IO.Path]::GetFileNameWithoutExtension($Theme))
        }

        $ThemeOutput | ExportTheme -Name $Name -Passthru:$Passthru -Scope:$Scope -Force:$Force -Update:$Update
    }
}
#EndRegion '.\Public\ConvertFrom-iTermColors.ps1'
#Region '.\Public\ConvertFrom-VSCodeTheme.ps1' 0
function ConvertFrom-VSCodeTheme {
    # .EXTERNALHELP Pansies-help.xml
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The name of (or full path to) a vscode json theme
        # E.g. 'Dark+' or 'Monokai'
        [Alias("PSPath", "Name")]
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Theme,

        # Overwrite any existing theme
        [switch]$Force,

        [switch]$Update,

        # Output the theme after importing it
        [switch]$Passthru,

        [ValidateSet("User", "Machine")]
        [string]$Scope = "User"
    )
    $ThemeSource = FindVsCodeTheme $Theme -ErrorAction Stop

    Write-Verbose "Importing $($ThemeSource.Path)"
    if($PSCmdlet.ShouldProcess($ThemeSource.Path, "Convert to $($ThemeSource.Name).theme.psd1")) {
        # Load the theme file and split the output into colors and tokencolors
        if($ThemeSource.Path.endswith(".json")) {
            $colors, $tokens = (ImportJsonIncludeLast $ThemeSource.Path).Where( {!$_.scope}, 'Split', 2)
        } else {
            $colors, $tokens = (Import-PList $ThemeSource.Path).settings.Where( {!$_.scope}, 'Split', 2)
            $colors = $colors.settings
        }

        # these should come from the colors, rather than the token scopes
        $DefaultTokenColor = GetColorProperty $colors 'editor.foreground', 'foreground', 'terminal.foreground'
        $SelectionColor = GetColorProperty $colors 'editor.selectionBackground', 'editor.selectionHighlightBackground', 'selection'
        $ErrorColor = @(@(GetColorProperty $colors 'errorForeground', 'editorError.foreground') + @(GetColorScopeForeground $tokens 'invalid'))[0]

        # I'm going to need some help figuring out what the best mappings are
        $CommandColor = GetColorScopeForeground $tokens 'support.function'
        $CommentColor = GetColorScopeForeground $tokens 'comment'
        $ContinuationPromptColor = GetColorScopeForeground $tokens 'constant.character'
        $EmphasisColor = GetColorScopeForeground $tokens 'markup.bold','markup.italic','emphasis','strong','constant.other.color', 'markup.heading'
        $KeywordColor = GetColorScopeForeground $tokens '^keyword.control$', '^keyword$', 'keyword.control', 'keyword'
        $MemberColor = GetColorScopeForeground $tokens 'variable.other.object.property', 'member', 'type.property', 'support.function.any-method', 'entity.name.function'
        $NumberColor = GetColorScopeForeground $tokens 'constant.numeric'
        $OperatorColor = GetColorScopeForeground $tokens 'keyword.operator$', 'keyword'
        $ParameterColor = GetColorScopeForeground $tokens 'parameter'
        $StringColor = GetColorScopeForeground $tokens '^string$'
        $TypeColor = GetColorScopeForeground $tokens '^storage.type$','^support.class$', '^entity.name.type.class$', '^entity.name.type$'
        $VariableColor = GetColorScopeForeground $tokens '^variable$', '^entity.name.variable$', '^variable.other$'


        $ThemeOutput = [Ordered]@{
            Name       = $ThemeSource.Name
            PSReadLine = @{
                Colors = @{
                    Command =            $CommandColor
                    Comment =            $CommentColor
                    ContinuationPrompt = $ContinuationPromptColor
                    DefaultToken =       $DefaultTokenColor
                    Emphasis =           $EmphasisColor
                    Error =              $ErrorColor
                    Keyword =            $KeywordColor
                    Member =             $MemberColor
                    Number =             $NumberColor
                    Operator =           $OperatorColor
                    Parameter =          $ParameterColor
                    Selection =          $SelectionColor
                    String =             $StringColor
                    Type =               $TypeColor
                    Variable =           $VariableColor
                }
            }
        }

        # If the VSCode Theme has terminal colors, export those
        if ($colors.'terminal.ansiBrightYellow') {
            Write-Verbose "Exporting ConsoleColors"
            $ThemeOutput['ConsoleColors'] = @(
                    GetColorProperty $colors "terminal.ansiBlack"
                    GetColorProperty $colors "terminal.ansiRed"
                    GetColorProperty $colors "terminal.ansiGreen"
                    GetColorProperty $colors "terminal.ansiYellow"
                    GetColorProperty $colors "terminal.ansiBlue"
                    GetColorProperty $colors "terminal.ansiMagenta"
                    GetColorProperty $colors "terminal.ansiCyan"
                    GetColorProperty $colors "terminal.ansiWhite"
                    GetColorProperty $colors "terminal.ansiBrightBlack"
                    GetColorProperty $colors "terminal.ansiBrightRed"
                    GetColorProperty $colors "terminal.ansiBrightGreen"
                    GetColorProperty $colors "terminal.ansiBrightYellow"
                    GetColorProperty $colors "terminal.ansiBrightBlue"
                    GetColorProperty $colors "terminal.ansiBrightMagenta"
                    GetColorProperty $colors "terminal.ansiBrightCyan"
                    GetColorProperty $colors "terminal.ansiBrightWhite"
                )
            if ($colors."terminal.background") {
                $ThemeOutput['ConsoleBackground'] = GetColorProperty $colors "terminal.background"
            }
            if ($colors."terminal.foreground") {
                $ThemeOutput['ConsoleForeground'] = GetColorProperty $colors "terminal.foreground"
            }
        }

        if (GetColorProperty $colors 'editorWarning.foreground') {
            $ThemeOutput['Host'] = @{
                'PrivateData' = @{
                    WarningForegroundColor  = GetColorProperty $colors 'editorWarning.foreground'
                    ErrorForegroundColor = GetColorProperty $Colors 'editorError.foreground'
                    VerboseForegroundColor = GetColorProperty $Colors 'editorInfo.foreground'
                    ProgressForegroundColor = GetColorProperty $Colors 'notifications.foreground'
                    ProgressBackgroundColor = GetColorProperty $Colors 'notifications.background'
                }
            }
        }

        if ($DebugPreference -in "Continue", "Inquire") {
            $global:colors = $colors
            $global:tokens = $tokens
            $global:Theme = $ThemeOutput
            ${function:global:Get-VSColorScope} = ${function:GetColorScopeForeground}
            ${function:global:Get-VSColor} = ${function:GetColorProperty}
            Write-Debug "For debugging, `$Theme, `$Colors, `$Tokens were copied to global variables, and Get-VSColor and Get-VSColorScope exported."
        }

        if ($ThemeOutput.PSReadLine.Colors.Values -contains $null) {
            Write-Warning "Some PSReadLine color values not set in '$($ThemeSource.Path)'"
        }

        $ThemeOutput | ExportTheme -Name $ThemeSource.Name -Passthru:$Passthru -Scope:$Scope -Force:$Force -Update:$Update
    }
}
#EndRegion '.\Public\ConvertFrom-VSCodeTheme.ps1'
#Region '.\Public\Export-PList.ps1' 0
function Export-PList {
    # .EXTERNALHELP Pansies-help.xml
    [CmdletBinding(SupportsShouldProcess)]
    param(
        # The object(s) to convert
        [Parameter(Mandatory, ValueFromPipeline)]
        [Alias("io")]
        [Object[]]$InputObject,

        # The path to an XML or binary plist file (e.g. a .tmTheme file)
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, Position = 0)]
        [Alias("PSPath")]
        [string]$Path,

        [switch]$Binary
    )

    begin {
        $Output = @()
    }
    process {
        $Output += $InputObject
    }
    end {
        $Parent = if($Parent = Split-Path $Path) {
            if(!(Test-Path -LiteralPath $Parent -PathType Container)) {
                New-Item -ItemType Directory -Path $Parent -Force
            }
            Convert-Path $Parent
        } else {
            Convert-Path (Get-Location -PSProvider FileSystem)
        }
        $Path = Join-Path $Parent -ChildPath (Split-Path $Path -Leaf)

        if($PSCmdlet.ShouldProcess($Path,"Export InputObject as PList $(if($Binary){'Binary'}else{'Xml'})") ) {
            if ($Binary) {
                [PoshCode.Pansies.Parsers.Plist]::WriteBinary($Output, $Path)
            } else {
                [PoshCode.Pansies.Parsers.Plist]::WriteXml($Output, $Path)
            }
        }
    }
}
#EndRegion '.\Public\Export-PList.ps1'
#Region '.\Public\Export-Theme.ps1' 0
function Export-Theme {
    # .EXTERNALHELP Pansies-help.xml
    [CmdletBinding()]
    param(
        # The name of the theme to export the current settings to
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [string]$Update,

        [switch]$Force,

        [switch]$Passthru,

        [ValidateSet("User", "Machine")]
        [string]$Scope = "User"
    )
    end {

        $ConsoleColors = (Get-ConsolePalette -AddScreenAndPopup)
        $Theme = [Ordered]@{
            Name = "$Name"
            # Force the colors to be saved as simple '#RRGGBB' instead of native (RgbColor '#RRGGBB')
            ConsoleForeground = $ConsoleColors[16].ToString()
            ConsoleBackground = $ConsoleColors[17].ToString()
            PopupForeground   = $ConsoleColors[18].ToString()
            PopupBackground   = $ConsoleColors[19].ToString()
            ConsoleColors     = $ConsoleColors[0..15].ForEach({$_.ToString()})
        }

        if($Host.Name -eq "ConsoleHost") {
            $Theme['Host'] = @{
                PrivateData = ConvertFrom-Metadata ($Host.PrivateData | Select-Object * | ConvertTo-Metadata -AsHashtable)
            }
        }

        if ((Get-Module PSReadLine).Version -ge "2.0.0") {
            $Theme['PSReadLine'] = @{
                # TODO: convert escape sequences to RGBColor values (e.g. 30's and 90's to colors, including 38;2;R;G;B;)
                Colors = ConvertFrom-Metadata -Ordered @(
                    Get-PSReadLineOption | Select-Object -Property @(
                        @{Name = "ContinuationPrompt"; Expression = { $_.ContinuationPromptColor }}
                        @{Name = "Parameter"; Expression = { $_.ParameterColor }}
                        @{Name = "Member"; Expression = { $_.MemberColor }}
                        @{Name = "Command"; Expression = { $_.CommandColor }}
                        @{Name = "Operator"; Expression = { $_.OperatorColor }}
                        @{Name = "Emphasis"; Expression = { $_.EmphasisColor }}
                        @{Name = "Selection"; Expression = { $_.SelectionColor }}
                        @{Name = "Variable"; Expression = { $_.VariableColor }}
                        @{Name = "Type"; Expression = { $_.TypeColor }}
                        @{Name = "Keyword"; Expression = { $_.KeywordColor }}
                        @{Name = "String"; Expression = { $_.StringColor }}
                        @{Name = "Error"; Expression = { $_.ErrorColor }}
                        @{Name = "Number"; Expression = { $_.NumberColor }}
                        @{Name = "Default"; Expression = { $_.DefaultTokenColor }}
                        @{Name = "Comment"; Expression = { $_.CommentColor }}
                    ) | ConvertTo-Metadata -AsHashtable )
            }
        }

        if($Update) {
            $Theme = ImportTheme $Name -ErrorAction SilentlyContinue | Update-Object $Theme
        }

        $Theme | ExportTheme -Name $Name -Passthru:$Passthru -Scope:$Scope -Force:$Force
    }
}
#EndRegion '.\Public\Export-Theme.ps1'
#Region '.\Public\Get-Complement.ps1' 0
function Get-Complement {
    # .EXTERNALHELP Pansies-help.xml
    [CmdletBinding()]
    [OutputType([PoshCode.Pansies.RgbColor])]
    param(
        # The source color to calculate the complement of
        [Parameter(ValueFromPipeline, Mandatory, Position = 0)]
        [PoshCode.Pansies.RgbColor]$Color,

        # Force the luminance to have "enough" contrast
        [switch]$ForceContrast,

        # Assume there are only 16 colors
        [switch]$ConsoleColor,

        # If set, output the input $Color before the complement
        [switch]$Passthru
    )
    process {
        if($ConsoleColor) {
            $Color = $Color.ConsoleColor
        }

        if($Passthru) { $Color }

        if($ConsoleColor) {
            if($Color.ToHunterLab().L -lt 50) {
                [PoshCode.Pansies.RgbColor][ConsoleColor]::White
            } else {
                [PoshCode.Pansies.RgbColor][ConsoleColor]::Black
            }
        } else {
            $Hsl = $Color.ToHsl()
            $Hsl.H = ($Hsl.H + 180) % 360

            if($ForceContrast) {
                $Lab = $Hsl.ToHunterLab()
                $Source = $Color.ToHunterLab()
                $Lab.L = ($Source.L + 50) % 100
                [PoshCode.Pansies.RgbColor]$Lab
            } else {
                [PoshCode.Pansies.RgbColor]$Hsl
            }
        }
    }
}
#EndRegion '.\Public\Get-Complement.ps1'
#Region '.\Public\Get-Gradient.ps1' 0
function Get-Gradient {
    # .EXTERNALHELP Pansies-help.xml
    [CmdletBinding()]
    [OutputType([PoshCode.Pansies.RgbColor[][]],[PoshCode.Pansies.RgbColor[]])]
    param(
        [Parameter(Mandatory, Position=0)]
        [PoshCode.Pansies.RgbColor]$StartColor,

        [Parameter(Mandatory, Position=1)]
        [PoshCode.Pansies.RgbColor]$EndColor,

        [Parameter(Position=2)]
        [Alias("Length","Count","Steps")]
        [int]$Width = $Host.UI.RawUI.WindowSize.Width,

        [Parameter(Position=3)]
        [int]$Height = 1,
        [ValidateSet("CMY","CMYK","LAB","LCH","LUV","HunterLAB","HSL","HSV","HSB","RGB","XYZ","YXY")]
        $ColorSpace = "HunterLab",

        [switch]$Reverse,

        [switch]$Flatten
    )

    $Height = [Math]::Max(1, $Height)
    $Width = [Math]::Max(1, $Width)
    $Colors = new-object PoshCode.Pansies.RgbColor[][] $Height, $Width

    # Simple pythagorean distance
    $Size = [Math]::Sqrt(($Height - 1) * ($Height - 1) + ($Width - 1) * ($Width - 1))

    $Left = $StartColor."To$ColorSpace"()
    $Right = $EndColor."To$ColorSpace"()
    $StepSize = New-Object "${ColorSpace}Color" -Property @{
        Ordinals = $(
            foreach ($i in 0..($Left.Ordinals.Count-1)) {
                ($Right.Ordinals[$i] - $Left.Ordinals[$i]) / $Size
            }
        )
    }
    Write-Verbose "Size: $('{0:N2}' -f $Size) ($Width x $Height) ($($Colors.Length) x $($Colors[0].Length))"
    Write-Verbose "Diff: {$StepSize}"
    Write-Verbose "From: {$Left} $($StartColor.Ordinals)"
    Write-Verbose "To:   {$Right} $($EndColor.Ordinals)"
    # For colors based on hue rotation, the math is slightly more complex:
    [bool]$RotatingColor = $StepSize | Get-Member H

    if($RotatingColor) {
        [Bool]$Change = [Math]::Abs($StepSize.H) -ge 180 / $Size
        if ($Reverse) { $Change = !$Change }
        if ($Change) {
            $StepSize.H = if ($StepSize.H -gt 0) {
                $StepSize.H - 360 / $Size
            } else {
                $StepSize.H + 360 / $Size
            }
        }
        $Ceiling = 360
    }

    for ($Line = 1; $Line -le $Height; $Line++) {
        for ($Column = 1; $Column -le $Width; $Column++) {
            $D = [Math]::Sqrt(($Line - 1) * ($Line - 1) + ($Column - 1) * ($Column - 1))

            $StepColor = New-Object "${ColorSpace}Color" -Property @{
                Ordinals = $(
                    foreach ($i in 0..$Left.Ordinals.Count) {
                        $Left.Ordinals[$i] + $StepSize.Ordinals[$i] * $D
                    }
                )
            }

            # For colors based on hue rotation, the math is slightly more complex:
            if($RotatingColor) {
                if($StepColor.H -lt 0) {
                    $StepColor.H += 360
                }
                $StepColor.H %= $Ceiling
            }
            $Ordinals1 = $StepColor.Ordinals

            $Colors[$Line - 1][$Column - 1] = $StepColor.ToRgb()
            $Ordinals2 = $Colors[$Line - 1][$Column - 1].Ordinals
            Write-Debug ("Step ${Line},${Column}: {0:N2}, {1:N2}, {2:N2}  =>  {3:N2}, {4:N2}, {5:N2}" -f $Ordinals1[0], $Ordinals1[1], $Ordinals1[2], $Ordinals2[0], $Ordinals2[1], $Ordinals2[2] )
        }
    }

    if ($Flatten) {
        $Colors.GetEnumerator().GetEnumerator()
    } else {
        ,$Colors
    }

}
#EndRegion '.\Public\Get-Gradient.ps1'
#Region '.\Public\Get-Theme.ps1' 0
function Get-Theme {
    # .EXTERNALHELP Pansies-help.xml
    [CmdletBinding()]
    param(
        # The name of the theme(s) to show. Supports wildcards, and defaults to * everything.
        [string]$Name = "*",

        # If set, only returns themes that include ConsoleColor
        [switch]$ConsoleColors,

        # If set, only returns themes that include PSReadline Colors
        [switch]$PSReadline
    )

    $Name = $Name -replace "((\.theme)?\.psd1)?$" -replace '$', ".theme.psd1"

    foreach($Theme in Join-Path $(
            Get-ConfigurationPath -Scope User -SkipCreatingFolder
            Get-ConfigurationPath -Scope Machine -SkipCreatingFolder
            Join-Path $PSScriptRoot Themes
        ) -ChildPath $Name -Resolve -ErrorAction Ignore ) {
            if ($ConsoleColors -or $PSReadline) {
                $ThemeData = Import-Metadata -Path $Theme
                if($ConsoleColors -and !$ThemeData.ConsoleColors) {
                    continue
                }
                if($PSReadline -and !$ThemeData.PSReadline) {
                    continue
                }
            }
            $Name = if($ThemeData.Name) {
                $ThemeData.Name
            } else {
                [IO.Path]::GetFileName($Theme) -replace "\.theme\.psd1$"
            }
            $Name | Add-Member NoteProperty PSPath $Theme -PassThru |
                    Add-Member NoteProperty Name $Name -PassThru
    }
}
#EndRegion '.\Public\Get-Theme.ps1'
#Region '.\Public\Import-PList.ps1' 0
function Import-PList {
    # .EXTERNALHELP Pansies-help.xml
    [CmdletBinding()]
    param(
        # The path to an XML or binary plist file (e.g. a .tmTheme file)
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [Alias("PSPath")]
        [string]$Path
    )

    process {
        $Path = Convert-Path $Path

        [PoshCode.Pansies.Parsers.Plist]::ReadPlist($Path)
    }
}
#EndRegion '.\Public\Import-PList.ps1'
#Region '.\Public\Import-Theme.ps1' 0
function Import-Theme {
    # .EXTERNALHELP Pansies-help.xml
    [CmdletBinding()]
    param(
        # A theme to import (can be the name of an installed PANSIES theme, or the full path to a psd1 file)
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [string]$Name,

        # By default, imported themes will update the default console colors (if they define console colors)
        # If SkipDefault is set, Import-Theme will leave the default Console Colors alone
        [switch]$SkipDefault
    )
    $Theme = ImportTheme $Name

    if ($ConsoleColors = $Theme.ConsoleColors) {
        Write-Verbose "Setting the console palette"

        # Handle setting the default foreground and background
        if($Theme.ConsoleBackground) {
            if($Theme.ConsoleForeground) {
                $ConsoleColors += [RgbColor]$Theme.ConsoleForeground
            } else {
                $ConsoleColors += Get-Complement $Theme.ConsoleBackground
            }
            $ConsoleColors += [RgbColor]$Theme.ConsoleBackground
        } elseif($Theme.ConsoleForeground) {
            $ConsoleColors += [RgbColor]$Theme.ConsoleForeground
            $ConsoleColors += Get-Complement $Theme.ConsoleForeground -ConsoleColor
        } else {
            # As a fall back, always force the background to black and the foreground to white
            # Because if you're in a default PowerShell window, you're using DarkYellow on DarkMagenta, which will be awful
            $ConsoleColors += [RgbColor]"White"
            $ConsoleColors += [RgbColor]"Black"
        }

        # Handle setting the popup foreground and background
        if($Theme.PopupBackground) {
            if($Theme.PopupForeground) {
                $ConsoleColors += [RgbColor]$Theme.PopupForeground
            } else {
                $ConsoleColors += Get-Complement $Theme.PopupBackground
            }
            $ConsoleColors += [RgbColor]$Theme.PopupBackground
        } elseif($Theme.PopupForeground) {
            $ConsoleColors += [RgbColor]$Theme.PopupForeground
            $ConsoleColors += Get-Complement $Theme.PopupForeground -ConsoleColor
        }

        Set-ConsolePalette -Colors $ConsoleColors -Default:(!$SkipDefault)
    }

    if ($PSReadLine = $Theme.PSReadLine) {
        Write-Verbose "Applying PSReadLineOptions"
        Set-PSReadLineOption @PSReadLine
    }

    if ($HostSettings = $Theme.Host) {
        function Update-Host {
            param($HostObject, $Settings)
            foreach ($key in $Settings.Keys) {
                try {
                    Write-Verbose "Applying Host settings: $key"
                    if ($HostObject.$key -is [ConsoleColor]) {
                        Write-Verbose "Converting '$($Settings.$Key)' to ConsoleColor"
                        $HostObject.$key = [ConsoleColor]([RgbColor]::ConsolePalette.FindClosestColorIndex([RgbColor]::new($Settings.$Key)))
                    } elseif ($Settings.$key -is [hashtable]) {
                        Update-Host $HostObject.$key $Settings.$Key
                    } else {
                        $HostObject.$key = $Settings.$Key
                    }
                } catch {
                    Write-Warning "Failed to apply Host '$key' = '$($Settings.$Key)' (it should have been a $($HostObject.$key.GetType().FullName)"
                }
            }
        }
        Update-Host $Host $HostSettings
    }
}
#EndRegion '.\Public\Import-Theme.ps1'
#Region '.\Public\Show-Theme.ps1' 0
function Show-Theme {
    # .EXTERNALHELP Pansies-help.xml
    [OutputType([string])]
    [CmdletBinding(DefaultParameterSetName="CurrentTheme")]
    param(
        [Alias("Theme","PSPath")]
        [Parameter(ValueFromPipelineByPropertyName)]
        [string]$Name,

        [Switch]$Tiny,

        [Switch]$MoreText,

        [Switch]$NoCodeSample
    )
    process {
        if(!$Name) {
            $Palette = Get-ConsolePalette
            ShowPreview $Palette @PSBoundParameters
        } else {
            foreach($Theme in Get-Theme $Name) {
                $Theme = ImportTheme $Theme.PSPath | Add-Member -Type NoteProperty -Name Name -Value $Theme.Name -Passthru -Force
                $Palette = $Theme.ConsoleColors
                $Syntax  = [PSCustomObject]$Theme.PSReadLine.Colors

                $PSBoundParameters['Name'] = $Theme.Name
                ShowPreview $Palette $Syntax @PSBoundParameters
            }
        }
    }
}
#EndRegion '.\Public\Show-Theme.ps1'

# SIG # Begin signature block
# MIIXzgYJKoZIhvcNAQcCoIIXvzCCF7sCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQURdS5IXaVML4Apda2VJyQCqNm
# V4qgghMBMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
# AQUFADCBizELMAkGA1UEBhMCWkExFTATBgNVBAgTDFdlc3Rlcm4gQ2FwZTEUMBIG
# A1UEBxMLRHVyYmFudmlsbGUxDzANBgNVBAoTBlRoYXd0ZTEdMBsGA1UECxMUVGhh
# d3RlIENlcnRpZmljYXRpb24xHzAdBgNVBAMTFlRoYXd0ZSBUaW1lc3RhbXBpbmcg
# Q0EwHhcNMTIxMjIxMDAwMDAwWhcNMjAxMjMwMjM1OTU5WjBeMQswCQYDVQQGEwJV
# UzEdMBsGA1UEChMUU3ltYW50ZWMgQ29ycG9yYXRpb24xMDAuBgNVBAMTJ1N5bWFu
# dGVjIFRpbWUgU3RhbXBpbmcgU2VydmljZXMgQ0EgLSBHMjCCASIwDQYJKoZIhvcN
# AQEBBQADggEPADCCAQoCggEBALGss0lUS5ccEgrYJXmRIlcqb9y4JsRDc2vCvy5Q
# WvsUwnaOQwElQ7Sh4kX06Ld7w3TMIte0lAAC903tv7S3RCRrzV9FO9FEzkMScxeC
# i2m0K8uZHqxyGyZNcR+xMd37UWECU6aq9UksBXhFpS+JzueZ5/6M4lc/PcaS3Er4
# ezPkeQr78HWIQZz/xQNRmarXbJ+TaYdlKYOFwmAUxMjJOxTawIHwHw103pIiq8r3
# +3R8J+b3Sht/p8OeLa6K6qbmqicWfWH3mHERvOJQoUvlXfrlDqcsn6plINPYlujI
# fKVOSET/GeJEB5IL12iEgF1qeGRFzWBGflTBE3zFefHJwXECAwEAAaOB+jCB9zAd
# BgNVHQ4EFgQUX5r1blzMzHSa1N197z/b7EyALt0wMgYIKwYBBQUHAQEEJjAkMCIG
# CCsGAQUFBzABhhZodHRwOi8vb2NzcC50aGF3dGUuY29tMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwPwYDVR0fBDgwNjA0oDKgMIYuaHR0cDovL2NybC50aGF3dGUuY29tL1Ro
# YXd0ZVRpbWVzdGFtcGluZ0NBLmNybDATBgNVHSUEDDAKBggrBgEFBQcDCDAOBgNV
# HQ8BAf8EBAMCAQYwKAYDVR0RBCEwH6QdMBsxGTAXBgNVBAMTEFRpbWVTdGFtcC0y
# MDQ4LTEwDQYJKoZIhvcNAQEFBQADgYEAAwmbj3nvf1kwqu9otfrjCR27T4IGXTdf
# plKfFo3qHJIJRG71betYfDDo+WmNI3MLEm9Hqa45EfgqsZuwGsOO61mWAK3ODE2y
# 0DGmCFwqevzieh1XTKhlGOl5QGIllm7HxzdqgyEIjkHq3dlXPx13SYcqFgZepjhq
# IhKjURmDfrYwggSjMIIDi6ADAgECAhAOz/Q4yP6/NW4E2GqYGxpQMA0GCSqGSIb3
# DQEBBQUAMF4xCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3Jh
# dGlvbjEwMC4GA1UEAxMnU3ltYW50ZWMgVGltZSBTdGFtcGluZyBTZXJ2aWNlcyBD
# QSAtIEcyMB4XDTEyMTAxODAwMDAwMFoXDTIwMTIyOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTQwMgYDVQQDEytT
# eW1hbnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIFNpZ25lciAtIEc0MIIBIjAN
# BgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAomMLOUS4uyOnREm7Dv+h8GEKU5Ow
# mNutLA9KxW7/hjxTVQ8VzgQ/K/2plpbZvmF5C1vJTIZ25eBDSyKV7sIrQ8Gf2Gi0
# jkBP7oU4uRHFI/JkWPAVMm9OV6GuiKQC1yoezUvh3WPVF4kyW7BemVqonShQDhfu
# ltthO0VRHc8SVguSR/yrrvZmPUescHLnkudfzRC5xINklBm9JYDh6NIipdC6Anqh
# d5NbZcPuF3S8QYYq3AhMjJKMkS2ed0QfaNaodHfbDlsyi1aLM73ZY8hJnTrFxeoz
# C9Lxoxv0i77Zs1eLO94Ep3oisiSuLsdwxb5OgyYI+wu9qU+ZCOEQKHKqzQIDAQAB
# o4IBVzCCAVMwDAYDVR0TAQH/BAIwADAWBgNVHSUBAf8EDDAKBggrBgEFBQcDCDAO
# BgNVHQ8BAf8EBAMCB4AwcwYIKwYBBQUHAQEEZzBlMCoGCCsGAQUFBzABhh5odHRw
# Oi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wNwYIKwYBBQUHMAKGK2h0dHA6Ly90
# cy1haWEud3Muc3ltYW50ZWMuY29tL3Rzcy1jYS1nMi5jZXIwPAYDVR0fBDUwMzAx
# oC+gLYYraHR0cDovL3RzLWNybC53cy5zeW1hbnRlYy5jb20vdHNzLWNhLWcyLmNy
# bDAoBgNVHREEITAfpB0wGzEZMBcGA1UEAxMQVGltZVN0YW1wLTIwNDgtMjAdBgNV
# HQ4EFgQURsZpow5KFB7VTNpSYxc/Xja8DeYwHwYDVR0jBBgwFoAUX5r1blzMzHSa
# 1N197z/b7EyALt0wDQYJKoZIhvcNAQEFBQADggEBAHg7tJEqAEzwj2IwN3ijhCcH
# bxiy3iXcoNSUA6qGTiWfmkADHN3O43nLIWgG2rYytG2/9CwmYzPkSWRtDebDZw73
# BaQ1bHyJFsbpst+y6d0gxnEPzZV03LZc3r03H0N45ni1zSgEIKOq8UvEiCmRDoDR
# EfzdXHZuT14ORUZBbg2w6jiasTraCXEQ/Bx5tIB7rGn0/Zy2DBYr8X9bCT2bW+IW
# yhOBbQAuOA2oKY8s4bL0WqkBrxWcLC9JG9siu8P+eJRRw4axgohd8D20UaF5Mysu
# e7ncIAkTcetqGVvP6KUwVyyJST+5z3/Jvz4iaGNTmr1pdKzFHTx/kuDDvBzYBHUw
# ggUwMIIEGKADAgECAhAECRgbX9W7ZnVTQ7VvlVAIMA0GCSqGSIb3DQEBCwUAMGUx
# CzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3
# dy5kaWdpY2VydC5jb20xJDAiBgNVBAMTG0RpZ2lDZXJ0IEFzc3VyZWQgSUQgUm9v
# dCBDQTAeFw0xMzEwMjIxMjAwMDBaFw0yODEwMjIxMjAwMDBaMHIxCzAJBgNVBAYT
# AlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2Vy
# dC5jb20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNp
# Z25pbmcgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQD407Mcfw4R
# r2d3B9MLMUkZz9D7RZmxOttE9X/lqJ3bMtdx6nadBS63j/qSQ8Cl+YnUNxnXtqrw
# nIal2CWsDnkoOn7p0WfTxvspJ8fTeyOU5JEjlpB3gvmhhCNmElQzUHSxKCa7JGnC
# wlLyFGeKiUXULaGj6YgsIJWuHEqHCN8M9eJNYBi+qsSyrnAxZjNxPqxwoqvOf+l8
# y5Kh5TsxHM/q8grkV7tKtel05iv+bMt+dDk2DZDv5LVOpKnqagqrhPOsZ061xPeM
# 0SAlI+sIZD5SlsHyDxL0xY4PwaLoLFH3c7y9hbFig3NBggfkOItqcyDQD2RzPJ6f
# pjOp/RnfJZPRAgMBAAGjggHNMIIByTASBgNVHRMBAf8ECDAGAQH/AgEAMA4GA1Ud
# DwEB/wQEAwIBhjATBgNVHSUEDDAKBggrBgEFBQcDAzB5BggrBgEFBQcBAQRtMGsw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcw
# AoY3aHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElE
# Um9vdENBLmNydDCBgQYDVR0fBHoweDA6oDigNoY0aHR0cDovL2NybDQuZGlnaWNl
# cnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDA6oDigNoY0aHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNybDBP
# BgNVHSAESDBGMDgGCmCGSAGG/WwAAgQwKjAoBggrBgEFBQcCARYcaHR0cHM6Ly93
# d3cuZGlnaWNlcnQuY29tL0NQUzAKBghghkgBhv1sAzAdBgNVHQ4EFgQUWsS5eyoK
# o6XqcQPAYPkt9mV1DlgwHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6chnfNtyA8w
# DQYJKoZIhvcNAQELBQADggEBAD7sDVoks/Mi0RXILHwlKXaoHV0cLToaxO8wYdd+
# C2D9wz0PxK+L/e8q3yBVN7Dh9tGSdQ9RtG6ljlriXiSBThCk7j9xjmMOE0ut119E
# efM2FAaK95xGTlz/kLEbBw6RFfu6r7VRwo0kriTGxycqoSkoGjpxKAI8LpGjwCUR
# 4pwUR6F6aGivm6dcIFzZcbEMj7uo+MUSaJ/PQMtARKUT8OZkDCUIQjKyNookAv4v
# cn4c10lFluhZHen6dGRrsutmQ9qzsIzV6Q3d9gEgzpkxYz0IGhizgZtPxpMQBvwH
# gfqL2vmCSfdibqFT+hKUGIUukpHqaGxEMrJmoecYpJpkUe8wggUwMIIEGKADAgEC
# AhALDZkX0sdOvwJhwzQTbV+7MA0GCSqGSIb3DQEBCwUAMHIxCzAJBgNVBAYTAlVT
# MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
# b20xMTAvBgNVBAMTKERpZ2lDZXJ0IFNIQTIgQXNzdXJlZCBJRCBDb2RlIFNpZ25p
# bmcgQ0EwHhcNMTgwNzEyMDAwMDAwWhcNMTkwNzE2MTIwMDAwWjBtMQswCQYDVQQG
# EwJVUzERMA8GA1UECBMITmV3IFlvcmsxFzAVBgNVBAcTDldlc3QgSGVucmlldHRh
# MRgwFgYDVQQKEw9Kb2VsIEguIEJlbm5ldHQxGDAWBgNVBAMTD0pvZWwgSC4gQmVu
# bmV0dDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAMJb3Cf3n+/pFJiO
# hQqN5m54FpyIktMRWe5VyF8465BnAtzw3ivMyN+3k8IoXQhMxpCsY1TJbLyydNR2
# QzwEEtGfcTVnlAJdFFlBsgIdK43waaML5EG7tzNJKhHQDiN9bVhLPTXrit80eCTI
# RpOA7435oVG8erDpxhJUK364myUrmSyF9SbUX7uE09CJJgtB7vqetl4G+1j+iFDN
# Xi3bu1BFMWJp+TtICM+Zc5Wb+ZaYAE6V8t5GCyH1nlAI3cPjqVm8y5NoynZTfOhV
# bHiV0QI2K5WrBBboR0q6nd4cy6NJ8u5axi6CdUhnDMH20NN2I0v+2MBkgLAzxPrX
# kjnaEGECAwEAAaOCAcUwggHBMB8GA1UdIwQYMBaAFFrEuXsqCqOl6nEDwGD5LfZl
# dQ5YMB0GA1UdDgQWBBTiwur/NVanABEKwjZDB3g6SZN1mTAOBgNVHQ8BAf8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwdwYDVR0fBHAwbjA1oDOgMYYvaHR0cDov
# L2NybDMuZGlnaWNlcnQuY29tL3NoYTItYXNzdXJlZC1jcy1nMS5jcmwwNaAzoDGG
# L2h0dHA6Ly9jcmw0LmRpZ2ljZXJ0LmNvbS9zaGEyLWFzc3VyZWQtY3MtZzEuY3Js
# MEwGA1UdIARFMEMwNwYJYIZIAYb9bAMBMCowKAYIKwYBBQUHAgEWHGh0dHBzOi8v
# d3d3LmRpZ2ljZXJ0LmNvbS9DUFMwCAYGZ4EMAQQBMIGEBggrBgEFBQcBAQR4MHYw
# JAYIKwYBBQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBOBggrBgEFBQcw
# AoZCaHR0cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0U0hBMkFzc3Vy
# ZWRJRENvZGVTaWduaW5nQ0EuY3J0MAwGA1UdEwEB/wQCMAAwDQYJKoZIhvcNAQEL
# BQADggEBADNNHuRAdX0ddONqaUf3H3pwa1K016C02P90xDIyMvw+hiUb4Z/xewnY
# jyplspD0NQB9ca2pnNIy1KwjJryRgq8gl3epSiWTbViVn6VDK2h0JXm54H6hczQ8
# sEshCW53znNVUUUfxGsVM9kMcwITHYftciW0J+SsGcfuuAIuF1g47KQXKWOMcUQl
# yrP5t0ywotTVcg/1HWAPFE0V0sFy+Or4n81+BWXOLaCXIeeryLYncAVUBT1DI6lk
# peRUj/99kkn+hz1q4hHTtfNpMTOApP64EEFGKICKkJdvhs1PjtGa+QdAkhcInTxk
# t/hIJPUb1nO4CsKp1gaVsRkkbcStJ2kxggQ3MIIEMwIBATCBhjByMQswCQYDVQQG
# EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNl
# cnQuY29tMTEwLwYDVQQDEyhEaWdpQ2VydCBTSEEyIEFzc3VyZWQgSUQgQ29kZSBT
# aWduaW5nIENBAhALDZkX0sdOvwJhwzQTbV+7MAkGBSsOAwIaBQCgeDAYBgorBgEE
# AYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwG
# CisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBRVPQOu
# ySNLvQlO6fsgRsVdntCA+zANBgkqhkiG9w0BAQEFAASCAQBjwrWAvnSbbmkyqHkb
# WuY93dwD0sxdQQrq4opFx/TBwNmCk2fzOZ33rYMKGvzCI8BLOVcEwKVEPNjZd3gD
# f304IV7DmHIA06PtzKw0yY+ErXgQ7lYd3+mKH7UzKkaH/VVN8mqlm6IEe+1s3pK0
# keJ2zKEIvQKoIX2icqqEu1pV9Ljm0Bb4k4a7euhxxvtstlu2+JmfjZKXxfekJXDZ
# A88ROiOQ0CmoGouhql9djRSP8DMr/MnVQdhX8l+b5JwL4hpKNSaykQ3iy+Td3N9f
# IZtitjeVkfsxqjOASlx3i2b3iqdxlVAXG5cFUTgN9hg2LCk8XCZAOvylH/9j87Gf
# E8XboYICCzCCAgcGCSqGSIb3DQEJBjGCAfgwggH0AgEBMHIwXjELMAkGA1UEBhMC
# VVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTAwLgYDVQQDEydTeW1h
# bnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIENBIC0gRzICEA7P9DjI/r81bgTY
# apgbGlAwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJ
# KoZIhvcNAQkFMQ8XDTE4MDkwODA0MTgzNlowIwYJKoZIhvcNAQkEMRYEFKbM82eL
# +Dm2UvpcQNO/jJGD+PHGMA0GCSqGSIb3DQEBAQUABIIBAGSrurklje8lyXtOH3k9
# ZmheMpbAJag6I8M4LrV03j0h737i+NeDdF04BMczCeiuBIanoVyZWspS8fWrkTZP
# axE9SysopFwYf/9UNgpEKruhasJ8k1o/9HLVjuqqem/1L+6XwZ5vTsXw2JIMzc0J
# rXBAGT3t1n2LAt6dEsYKl7tGnf1a8VLqn/4EVtDQSUe8dyOgPsfsvDztkJCPIJuw
# 2boOhdjtZ/MBozfYrRS0H+RweKHZS71Xez6FL3woLxSEo7rO15Xz/c+mn0gJrhEi
# RjtshH4uPQsqu5F5hnBd13jCEdiH9SzooO6YhiqjBE4TXMMHEkmDvYJXGxl6N3f6
# qRc=
# SIG # End signature block
