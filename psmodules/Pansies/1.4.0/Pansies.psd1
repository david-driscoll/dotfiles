@{
    # The module version should be SemVer.org compatible
    ModuleVersion           = '1.4.0'

    # PrivateData is where all third-party metadata goes
    PrivateData = @{
        # PrivateData.PSData is the PowerShell Gallery data
        PSData = @{
            # Prerelease string of this module
            Prerelease      = '-beta03'

            # ReleaseNotes of this module
            ReleaseNotes    = '
            1.4.0-beta: Add commands to expose the console palette features
                        New palette commands: Get-ConsolePalette, Set-ConsolePalette, Convert-ConsolePalette

                        Add color "themes" which include console palettes, PSReadLine, and ConsoleHost PrivateData
                        New theme commands: Get-Theme, Show-Theme, Import-Theme, Export-Theme
                        Also: ConverFrom-VSCodeTheme and ConvertFrom-iTermColors

                        Added Import-PList (needed for VSCode and iTermColors converters) and Export-PList
            1.3.0:      Add support for x11 color names to make the drives more useful
                        Add a RgbColor content provider that can convert colors to their escape sequences
                        Add Fg: drive and Bg: drive so you can "$Fg:Red$Bg:Blue$YourMessage"
            '

            # Tags applied to this module. These help with module discovery in online galleries.
            Tags            = 'ANSI','EscapeSequences','VirtualTerminal','Color'

            # A URL to the license for this module.
            LicenseUri      = 'https://github.com/PoshCode/Pansies/blob/master/LICENSE'

            # A URL to the main website for this project.
            ProjectUri      = 'https://github.com/PoshCode/Pansies'

            # A URL to an icon representing this module.
            IconUri         = 'https://github.com/PoshCode/Pansies/blob/resources/Pansies_32.gif?raw=true'
        } # End of PSData
    } # End of PrivateData

    # Script module or binary module file associated with this manifest.
    RootModule              = 'Pansies.psm1'

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules           = @( "lib\Pansies.dll" )

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules         = @('Configuration')

    # Format files (.ps1xml) to be loaded when importing this module
    FormatsToProcess        = 'Pansies.format.ps1xml'

    # Always define FunctionsToExport as an empty @() which will be replaced on build
    FunctionsToExport       = @('Convert-ConsolePalette','ConvertFrom-iTermColors','ConvertFrom-VSCodeTheme','Export-PList','Export-Theme','Get-Complement','Get-Gradient','Get-Theme','Import-PList','Import-Theme','Show-Theme')

    # Cmdlets to export from this module
    CmdletsToExport         = @('New-Text', 'Write-Host', 'Get-ConsolePalette', 'Set-ConsolePalette')

    # Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
    AliasesToExport         = 'Text'

    # ID used to uniquely identify this module
    GUID                    = '6c376de1-1baf-4d52-9666-d46f6933bc16'
    Description             = 'A PowerShell module for handling color and cursor positioning via ANSI escape sequences'

    # Common stuff for all our modules:
    CompanyName             = 'PoshCode'
    Author                  = 'Joel Bennett'
    Copyright               = 'Copyright 2018 Joel Bennett'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion       = '5.1'
    CompatiblePSEditions    = @('Core','Desktop')
}



# SIG # Begin signature block
# MIIXzgYJKoZIhvcNAQcCoIIXvzCCF7sCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUUj0YBj7oAE499RkLUHwJRHBW
# JR2gghMBMIID7jCCA1egAwIBAgIQfpPr+3zGTlnqS5p31Ab8OzANBgkqhkiG9w0B
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
# CisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSRlI8d
# V9DZ0sBwajqrShwkSwjDhzANBgkqhkiG9w0BAQEFAASCAQByfwodpTAOOJoMCXqv
# 3P7T5fQwu4VrmB8+j8BP7bhFoByS5KvhQRsWShBt9w2la0VjPjeTWxqDnqhYV822
# GeEIeZC2S7fpGmNezxPTf8pZQGpSxz72ehboFgeguV6AyK3juVxxCWjIdsDi8C8k
# 5kkitlQmRxZ6ZmVw23YOFQkJcGW/e8NBeh6stPlLXgeQN6HX7V0otETbIwD5LgZM
# wpuvaXRWsMGaU2lbSd9sWg3GIwT5bGqqOvzlomldjoUYCG8qSd8wKLpdK3YsIiTQ
# ThM0+gb724ffZdiC6e6OHXJUaQZy7F5ucSONE1V5fS7V4CVWa3SuWO6tlkwfdc0k
# qwjYoYICCzCCAgcGCSqGSIb3DQEJBjGCAfgwggH0AgEBMHIwXjELMAkGA1UEBhMC
# VVMxHTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMTAwLgYDVQQDEydTeW1h
# bnRlYyBUaW1lIFN0YW1waW5nIFNlcnZpY2VzIENBIC0gRzICEA7P9DjI/r81bgTY
# apgbGlAwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEwHAYJ
# KoZIhvcNAQkFMQ8XDTE4MDkwODA0MTgzNVowIwYJKoZIhvcNAQkEMRYEFEWjH7l3
# YbRhIxwClRp4Gfhbu69xMA0GCSqGSIb3DQEBAQUABIIBACo/SmkDE3Uv6JXTjiXa
# QE41i6zhrhQ1+RID4P00A/NaEK4Q8AzQvK5uLXmFr/AhEEXMmP6RE/ZX7Rotgsts
# ZIuguQ07hXxKg1EdeZf7PXOWWqsSSXBzh5vMFzsGdlN1GtXudxnrcy15P2o6WSmE
# VSNPkLlQMLoDjilGmVTAlxDBGlQymWLslnnbDEofINWiQfa6ZVyU+r2LbHechmss
# Kjme5dRh2dznP8YlaRPGDSIJnGOnKV6ajEpMw2w7b9PNwzt/Ub/gMN2GjBEmXTFx
# 91Kt3S2od2JpT2geuKRTA+zymeGfCVztELHE8ZxvmjdWhaMVcOk950H23PF4iBUl
# NwY=
# SIG # End signature block
