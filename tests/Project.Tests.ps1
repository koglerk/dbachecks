$packages = get-package
if ($packages.Name  -contains "PSScriptAnalyzer") {
    #PSScriptAnalyzer is installed on the system
} else {
    Write-Output "Installing latest version of PSScriptAnalyzer"

    #install PSScriptAnalyzer
    Install-Package PSScriptAnalyzer -Force -Scope CurrentUser
}
$script:ModuleName = 'dbachecks'
# Removes all versions of the module from the session before importing
Get-Module $ModuleName | Remove-Module
$ModuleBase = Split-Path -Parent $MyInvocation.MyCommand.Path
$FunctionHelpTestExceptions = Get-Content -Path "$ModuleBase\Help.Exceptions.ps1"
# For tests in .\Tests subdirectory
if ((Split-Path $ModuleBase -Leaf) -eq 'Tests') {
    $ModuleBase = Split-Path $ModuleBase -Parent
}
Import-Module $ModuleBase\$ModuleName.psd1 -PassThru -ErrorAction Stop | Out-Null
Describe "PSScriptAnalyzer rule-sets" -Tag Build , ScriptAnalyzer {

    $Rules = Get-ScriptAnalyzerRule
    $scripts = Get-ChildItem $ModuleBase -Include *.ps1, *.psm1, *.psd1 -Recurse | Where-Object fullname -notmatch 'classes'

    foreach ( $Script in $scripts )
    {
        Context "Script '$($script.FullName)'" {

            foreach ( $rule in $rules )
            {
                                # Skip all rules that are on the exclusions list
                if ($FunctionHelpTestExceptions -contains $rule.RuleName) { continue }
                It "The Script Analyzer Rule [$rule] Should not fail" {
                    $rulefailures = Invoke-ScriptAnalyzer -Path $script.FullName -IncludeRule $rule.RuleName -Settings $ModuleBase\PSScriptAnalyzerSettings.psd1
                    $message = ($rulefailures | Select-Object Message -Unique).Message
                    $lines = $rulefailures.Line -join ','
                    $rulefailures.Count | Should -Be 0 -Because "Script Analyzer says the rules have been broken on lines $lines with Message '$message' Check in VSCode Problems tab or Run Invoke-ScriptAnalyzer -Script $($script.FullName) -Settings $ModuleBase\PSScriptAnalyzerSettings.psd1"
                }
            }
        }
    }
}


Describe "General project validation: $moduleName" -Tags Build {
    BeforeAll {
        Get-Module $ModuleName | Remove-Module
    }
    It "Module '$moduleName' can import cleanly" {
        {Import-Module $ModuleBase\$ModuleName.psd1 -force } | Should Not Throw
    }
}