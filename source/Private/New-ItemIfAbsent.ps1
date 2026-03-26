function New-ItemIfAbsent {
    [CmdletBinding()]
    [OutputType([void])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Internal helper — ShouldProcess is owned by the calling function.')]
    param (
        [Parameter(Position = 0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path,

        [Parameter(Position = 1)]
        [ValidateSet('Directory', 'File')]
        [string]
        $Type = 'Directory',

        # Only applies when $Type = 'Directory'; marks system directories as hidden
        [switch]
        $Hidden
    )

    if (-not (Test-Path -Path $Path)) {
        New-Item -Path $Path -ItemType $Type -Force | Out-Null

        if ($Hidden -and $Type -eq 'Directory') {
            $item = Get-Item -Path $Path -Force
            $item.Attributes = $item.Attributes -bor [System.IO.FileAttributes]::Hidden
        }
    }
}
