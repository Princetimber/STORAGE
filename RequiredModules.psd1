@{
    <#
        This is only required if you need to use the method PowerShellGet & PSDepend
        It is not required for PSResourceGet or ModuleFast (and will be ignored).
        See Resolve-Dependency.psd1 on how to enable methods.
    #>
    #PSDependOptions             = @{
    #    AddToPath  = $true
    #    Target     = 'output\RequiredModules'
    #    Parameters = @{
    #        Repository = 'PSGallery'
    #    }
    #}

    <#
        NuGet-style interval ranges need a leading ':' for ModuleFast (the default
        resolver, see Resolve-Dependency.psd1's UseModuleFast) to parse them, e.g.
        'ModuleName:[3.0,4.0)'. Resolve-Dependency.ps1's ModuleFast branch builds this
        by concatenating the module name directly with this value, so the colon must
        live here. This is not valid syntax for the legacy PSDepend resolver.
    #>
    InvokeBuild                 = ':[5.0,6.0)'
    PSScriptAnalyzer            = ':[1.22,2.0)'
    Pester                      = ':[5.6,6.0)'
    ModuleBuilder               = ':[3.0,4.0)'
    ChangelogManagement         = ':[3.0,4.0)'
    Sampler                     = ':[0.118,1.0)'
    'Sampler.GitHubTasks'       = ':[0.4,1.0)'
}
