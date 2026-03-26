#Requires -Version 7.0

<#
    This file is intentionally left here for the module manifest to refer to.
    It is recreated during the build process by Sampler/ModuleBuilder, which
    inlines all Public/ and Private/ function definitions into a compiled .psm1
    in the output/ folder.

    During development (before building), this file dot-sources all .ps1 files
    from Private/ and Public/ so the module can be imported directly from source.
    Do not add runtime logic here that you expect to survive the build — use
    prefix.ps1 or suffix.ps1 for that.
#>

# dot-Source Private functions
$PrivateFunctions = Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -Recurse
foreach ($function in $PrivateFunctions) {
   try {
      . $function.FullName
   } catch {
      Write-Warning "Failed to dot-source private function file: $($function.FullName). Error: $($_.Exception.Message)"
   }
}

# dot-Source Public functions
$PublicFunctions = Get-ChildItem -Path $PSScriptRoot\Public\*.ps1 -Recurse
foreach ($function in $PublicFunctions) {
   try {
      . $function.FullName
      Export-ModuleMember -Function $function.BaseName
   } catch {
      Write-Warning "Failed to dot-source public function file: $($function.FullName). Error: $($_.Exception.Message)"
   }
}
