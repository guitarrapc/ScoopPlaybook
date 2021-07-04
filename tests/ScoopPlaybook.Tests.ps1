$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

InModuleScope "ScoopPlaybook" {
    Describe "Pre execute Test" {
        Context "When there are scoop installed" {
            BeforeEach {
                Mock Write-Host { } -Verifiable
            }
            It "scoop is installed" {
                { scoop } | Should -Not -Throw
            }
            It "prerequisites will not fail if scoop is installed." {
                { Prerequisites } | Should -Not -Throw
            }
            It "UpdateScoop will not fail if scoop is installed." {
                { UpdateScoop } | Should -Not -Throw
            }
            It "runtime check should be pass when latest scoop installed" {
                { RuntimeCheck } | Should -Not -Throw
            }
        }
    }
    foreach ($mode in "run", "check") {
        $env:Mode = $mode
        $env:templatePath = "tests/templates"
        Describe "PlaybookTest success pattern" {
            Context "When site.yaml and task is valid" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "installing package role should not throw (mode: $env:Mode)" {
                    { RunMain -BaseYaml "$env:templatePath/success.yml" -Mode $env:MODE } | Should -Not -Throw
                }
                It "uninstalling package role should not throw (mode: $env:Mode)" {
                    { RunMain -BaseYaml "$env:templatePath/uninstall.yml" -Mode $env:MODE } | Should -Not -Throw
                }
            }
        }
        Describe "PlaybookTest fail pattern" {
            Context "When site.yaml is not exists" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "not existing playbook should throw (mode: $env:Mode)" {
                    { RunMain -BaseYaml "noneexitpath.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When tasks dir is missing" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify no task dir should throw (mode: $env:Mode)" {
                    { RunMain -BaseYaml "$env:templatePath/notaskdir.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When package is not exists in task" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify non existing package should throw (mode: $env:Mode)" {
                    { RunMain -BaseYaml "$env:templatePath/nonexistingpackage.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When task missing bucket prop" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "installing package should throw (mode: $env:Mode)" {
                    { RunMain -BaseYaml "$env:templatePath/missingbucket.yml" -Mode $env:MODE } | Should -Throw
                }
                It "uninstalling package  should throw (mode: $env:Mode)" {
                    { RunMain -BaseYaml "$env:templatePath/missingbucketuninstall.yml" -Mode $env:MODE } | Should -Throw
                }
            }

            Context "When site.yaml is empty" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify empty playbook should throw (mode: $env:Mode)" {
                    { RunMain -BaseYaml "$env:templatePath/empty.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When site.yaml role is missing" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify missing role playbook should throw (mode: $env:Mode)" {
                    { RunMain -BaseYaml "$env:templatePath/missingrole.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When site.yaml target invalid role name" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify invalid role playbook should throw (mode: $env:Mode)" {
                    { RunMain -BaseYaml "$env:templatePath/invalidrole.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When task file is missing" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify no task should not throw (mode: $env:Mode)" {
                    { RunMain -BaseYaml "$env:templatePath/notaskfile.yml" -Mode $env:MODE } | Should -Throw
                }
            }
        }
    }
}
Remove-Module ScoopPlaybook -Force
