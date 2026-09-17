#Requires -Version 7.0

# Wraps Copy-Item for Pester mocking.
function Copy-ItemWrapper {
    [CmdletBinding()]
    [OutputType([void])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Wrapper function; ShouldProcess handled by calling function.')]
    param(
        [Parameter(Mandatory)]
        [string]$LiteralPath,

        [Parameter(Mandatory)]
        [string]$Destination
    )

    Copy-Item -LiteralPath $LiteralPath -Destination $Destination
}
