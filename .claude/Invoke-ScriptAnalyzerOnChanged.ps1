#Requires -Version 7.0
# Runs ScriptAnalyzer against PS files that are modified relative to HEAD.
# Called by both the PostToolUse and SessionStart hooks in settings.json.

$files = (git diff HEAD --name-only --diff-filter=AMR -- '*.ps1' '*.psm1') -split "`r?`n" |
    Where-Object { $_ }

if ($files) {
    Invoke-ScriptAnalyzer -Path $files -Settings PSScriptAnalyzerSettings.psd1 -Severity Warning, Error
}
