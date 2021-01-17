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
    Describe "PlaybookTest success pattern" {
        Context "When site.yaml and task is valid" {
            BeforeEach {
                Mock Write-Host { } -Verifiable
            }
            foreach ($mode in "run", "check") {
                $env:Mode = $mode
                $env:templatePath = "tests/templates"
                It "installing package role should not throw" {
                    { RunMain -BaseYaml "$env:templatePath/success.yml" -Mode $env:MODE } | Should -Not -Throw
                }
                It "uninstalling package role should not throw" {
                    { RunMain -BaseYaml "$env:templatePath/uninstall.yml" -Mode $env:MODE } | Should -Not -Throw
                }
            }
        }
    }
    Describe "PlaybookTest skip pattern" {
        Context "When site.yaml is empty" {
            BeforeEach {
                Mock Write-Host { } -Verifiable
            }
            foreach ($mode in "run", "check") {
                $env:Mode = $mode
                $env:templatePath = "tests/templates"
                It "verify empty playbook should not throw" {
                    { RunMain -BaseYaml "$env:templatePath/empty.yml" -Mode $env:MODE } | Should -Not -Throw
                }
                It "verify empty playbook should return null" {
                    RunMain -BaseYaml "$env:templatePath/empty.yml" -Mode $env:MODE | Should -BeNullOrEmpty 
                }
            }
        }
        Context "When site.yaml role is missing" {
            BeforeEach {
                Mock Write-Host { } -Verifiable
            }
            foreach ($mode in "run", "check") {
                $env:Mode = $mode
                $env:templatePath = "tests/templates"
                It "verify missing role playbook should throw" {
                    { RunMain -BaseYaml "$env:templatePath/missingrole.yml" -Mode $env:MODE } | Should -Not -Throw
                }
                It "verify missing role playbook should return null" {
                    RunMain -BaseYaml "$env:templatePath/missingrole.yml" -Mode $env:MODE | Should -BeNullOrEmpty
                }
            }
        }
        Context "When site.yaml target invalid role name" {
            BeforeEach {
                Mock Write-Host { } -Verifiable
            }
            foreach ($mode in "run", "check") {
                $env:Mode = $mode
                $env:templatePath = "tests/templates"
                It "verify invalid role playbook should throw" {
                    { RunMain -BaseYaml "$env:templatePath/invalidrole.yml" -Mode $env:MODE} | Should -Not -Throw
                }
                It "verify invalid role playbook should return null" {
                    RunMain -BaseYaml "$env:templatePath/invalidrole.yml" -Mode $env:MODE | Should -BeNullOrEmpty
                }
            }
        }
        Context "When task is empty" {
            BeforeEach {
                Mock Write-Host { } -Verifiable
            }
            foreach ($mode in "run", "check") {
                $env:Mode = $mode
                $env:templatePath = "tests/templates"
                It "verify no task should not throw" {
                    { RunMain -BaseYaml "$env:templatePath/notask.yml" -Mode $env:MODE } | Should -Not -Throw
                }
            }
        }
    }
    Describe "PlaybookTest fail pattern" {
        Context "When site.yaml is not exists" {
            BeforeEach {
                Mock Write-Host { } -Verifiable
            }
            foreach ($mode in "run", "check") {
                $env:Mode = $mode
                $env:templatePath = "tests/templates"
                It "not existing playbook should throw" {
                    { RunMain -BaseYaml "noneexitpath.yml" -Mode $env:MODE } | Should -Throw
                }
            }
        }
        Context "When package is not exists in task" {
            BeforeEach {
                Mock Write-Host { } -Verifiable
            }
            foreach ($mode in "run", "check") {
                $env:Mode = $mode
                $env:templatePath = "tests/templates"
                It "verify non existing package should throw" {
                    { RunMain -BaseYaml "$env:templatePath/nonexistingpackage.yml" -Mode $env:MODE } | Should -Throw
                }
            }
        }
        Context "When task missing bucket prop" {
            BeforeEach {
                Mock Write-Host { } -Verifiable
            }
            foreach ($mode in "run", "check") {
                $env:Mode = $mode
                $env:templatePath = "tests/templates"
                It "installing package should throw" {
                    { RunMain -BaseYaml "$env:templatePath/missingbucket.yml" -Mode $env:MODE } | Should -Throw
                }
                It "uninstalling package  should throw" {
                    { RunMain -BaseYaml "$env:templatePath/missingbucketuninstall.yml" -Mode $env:MODE } | Should -Throw
                }
            }
        }
    }
}
Remove-Module ScoopPlaybook -Force
