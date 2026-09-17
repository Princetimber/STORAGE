#Requires -Version 7.0

# Wraps Clear-Content for Pester mocking.
function Clear-ContentWrapper {
    [CmdletBinding()]
    [OutputType([void])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Wrapper function; ShouldProcess handled by calling function.')]
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath
    )

    Clear-Content -LiteralPath $LiteralPath
}
