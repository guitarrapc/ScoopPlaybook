$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

InModuleScope ScoopPlaybook {
    Describe "Pre execute Test" {
        Context "When there are scoop installed" {
            BeforeEach {
                Mock Write-Host { } -Verifiable
            }
            It "scoop is installed" {
                { scoop } | Should -Not -Throw
            }
            It "ValidateScoopInstall will not fail if scoop is installed." {
                { ValidateScoopInstall } | Should -Not -Throw
            }
            It "UpdateScoop will not fail if scoop is installed." {
                { UpdateScoop } | Should -Not -Throw
            }
            It "scoop status should be pass when latest scoop installed" {
                { ScoopStatus } | Should -Not -Throw
            }
        }
    }
    Describe "Scoop version Test" {
        Context "When Scoop Version command is valid" {
            It "scoop info running without error" {
                { scoop info git } | Should -Not -Throw
            }
            It "GetScoopVersion run successfully" {
                { GetScoopVersion } | Should -Not -Throw
            }
        }
        Context "Scoop command output Type is valid" {
            It "scoop checkup output type is desired" {
                (ScoopCmdCheckup | Select-Object -first 1).GetType().FullName | Should -Be "System.Management.Automation.InformationRecord"
            }
            It "scoop info output type is desired" {
                $version = GetScoopVersion
                if ($version -eq [ScoopVersionInfo]::version_0_1_0_or_higher) {
                    (ScoopCmdInfo -App git | Select-Object -first 1).GetType().FullName | Should -Be "System.Management.Automation.PSCustomObject"
                }
                elseif ($version -eq [ScoopVersionInfo]::version_0_0_1_and_lower) {
                    (ScoopCmdInfo -App git | Select-Object -first 1).GetType().FullName | Should -Be "System.String"
                }
                else {
                    (ScoopCmdInfo -App git | Select-Object -first 1).GetType().FullName | Should -Be "System.String"
                }
            }
            It "scoop list output type is desired" {
                $version = GetScoopVersion
                if ($version -eq [ScoopVersionInfo]::version_0_1_0_or_higher) {
                    (ScoopCmdList -App git | Select-Object -first 1).GetType().FullName | Should -Be "ScoopApps"
                }
                elseif ($version -eq [ScoopVersionInfo]::version_0_0_1_and_lower) {
                    (ScoopCmdList -App git | Select-Object -first 1).GetType().FullName | Should -Be "System.Management.Automation.InformationRecord"
                }
                else {
                    (ScoopCmdList -App git | Select-Object -first 1).GetType().FullName | Should -Be "System.Management.Automation.InformationRecord"
                }
            }
            It "scoop update app output type is desired" {
                (ScoopCmdUpdate -App git | Select-Object -first 1).GetType().FullName | Should -Be "System.Management.Automation.InformationRecord"
            }
            It "scoop status app output type is desired" {
                ScoopCmdStatus -App git | ForEach-Object { $_.GetType().FullName } | Sort-Object -Unique | Should -BeIn @("System.Management.Automation.InformationRecord", "System.String")
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

        Describe "Playbook Verify fail pattern" {
            Context "When site.yaml is not exists" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "not existing playbook should throw (mode: $env:Mode)" {
                    { VerifyYaml -BaseYaml "noneexitpath.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When tasks dir is missing" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify no task dir should throw (mode: $env:Mode)" {
                    { VerifyYaml -BaseYaml "$env:templatePath/notaskdir.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When site.yaml is empty" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify empty playbook should throw (mode: $env:Mode)" {
                    { VerifyYaml -BaseYaml "$env:templatePath/empty.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When site.yaml role is missing" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify missing role playbook should throw (mode: $env:Mode)" {
                    { VerifyYaml -BaseYaml "$env:templatePath/missingrole.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When site.yaml target invalid role name" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify invalid role playbook should throw (mode: $env:Mode)" {
                    { VerifyYaml -BaseYaml "$env:templatePath/invalidrole.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When task file is missing" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify no task should not throw (mode: $env:Mode)" {
                    { VerifyYaml -BaseYaml "$env:templatePath/notaskfile.yml" -Mode $env:MODE } | Should -Throw
                }
            }
        }

        Describe "PlaybookTest fail pattern" {
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
        }
    }
}
Remove-Module ScoopPlaybook -Force
