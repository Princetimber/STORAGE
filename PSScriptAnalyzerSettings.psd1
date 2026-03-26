@{
    # PSUseBOMForUnicodeEncodedFile is a Windows-legacy rule.
    # PowerShell 7+ on macOS/Linux creates UTF-8 without BOM by default.
    # This project targets PS7+ cross-platform, so the rule is suppressed globally.
    ExcludeRules = @(
        'PSUseBOMForUnicodeEncodedFile'
    )
}
