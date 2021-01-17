#requires -Modules PSScriptAnalyzer

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Resolve-Path "$here/.."
Describe "Lint: PSScriptAnalyzer" {
    $env:repoRoot = $repoRoot
    It "File '$($_.Name)' passes PSScriptAnalyzer rules" {
        $message = (Invoke-ScriptAnalyzer -Path "$env:repoRoot/src/ScoopPlaybook.psm1" -Settings $env:repoRoot/PSScriptAnalyzerSettings.psd1 -Severity Warning).Message
        $message | Should -BeNullOrEmpty
    }
}
