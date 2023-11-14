$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

BeforeAll {
    scoop install 7zip
    scoop uninstall bat
}
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
                { scoop info 7zip } | Should -Not -Throw
            }
            It "GetScoopVersion run successfully" {
                { GetScoopVersion } | Should -Not -Throw
            }
        }
        Context "Scoop command output Type is valid" {
            It "scoop checkup output type is desired" {
                (ScoopCmdCheckup | Select-Object | Get-Member).TypeName | Sort-Object -Unique | Should -Be "System.Management.Automation.InformationRecord"
            }
            It "scoop info output type is desired" {
                $version = GetScoopVersion
                if ($version -eq [ScoopVersionInfo]::version_0_1_0_or_higher) {
                    (ScoopCmdInfo -App 7zip | Get-Member).TypeName | Sort-Object -Unique | Should -Be "System.Management.Automation.PSCustomObject"
                }
                elseif ($version -eq [ScoopVersionInfo]::version_0_0_1_and_lower) {
                    (ScoopCmdInfo -App 7zip | Get-Member).TypeName | Sort-Object -Unique | Should -Be "System.String"
                }
                else {
                    (ScoopCmdInfo -App 7zip | Get-Member).TypeName | Sort-Object -Unique | Should -Be "System.String"
                }
            }
            It "scoop install output type is desired" {
                # 1st run contains string and InformationRecord
                (ScoopCmdInstall -App bat | Select-Object | Get-Member).TypeName | Sort-Object -Unique | Should -BeIn @("System.Management.Automation.InformationRecord", "System.String")
                # 2nd run only contains InformationRecord
                (ScoopCmdInstall -App bat | Select-Object | Get-Member).TypeName | Sort-Object -Unique | Should -Be "System.Management.Automation.InformationRecord"
            }
            It "scoop list output type is desired" {
                $version = GetScoopVersion
                if ($version -eq [ScoopVersionInfo]::version_0_1_0_or_higher) {
                    (ScoopCmdList -App 7zip | Get-Member).TypeName | Sort-Object -Unique | Should -Be "ScoopApps"
                }
                elseif ($version -eq [ScoopVersionInfo]::version_0_0_1_and_lower) {
                    (ScoopCmdList -App 7zip | Get-Member).TypeName | Sort-Object -Unique | Should -Be "System.Management.Automation.InformationRecord"
                }
                else {
                    (ScoopCmdList -App 7zip | Get-Member).TypeName | Sort-Object -Unique | Should -Be "System.Management.Automation.InformationRecord"
                }
            }
            It "scoop uninstall output type is desired" {
                (ScoopCmdUninstall -App bat | Select-Object | Get-Member).TypeName | Sort-Object -Unique | Should -BeIn @("System.Management.Automation.InformationRecord", "System.String")
            }
            It "scoop update app output type is desired" {
                (ScoopCmdUpdate -App 7zip | Get-Member).TypeName | Sort-Object -Unique | Should -Be "System.Management.Automation.InformationRecord"
            }
            It "scoop status app output type is desired" {
                # InvalidOperationException: You must specify an object for the Get-Member cmdlet. <- cannot resolve....
                # (ScoopCmdStatus | Get-Member).TypeName | Sort-Object -Unique | Should -Be "ScoopStatus"
            }
        }
    }
    foreach ($mode in "check", "run") {
        $env:Mode = $mode
        $env:templatePath = "tests/templates"
        Describe "Playbook Verify Test (mode: $env:Mode)" {
            Context "When site.yaml is not exists" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "not existing playbook should throw" {
                    { VerifyYaml -BaseYaml "noneexitpath.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When tasks dir is missing" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify no task dir should throw" {
                    { VerifyYaml -BaseYaml "$env:templatePath/notaskdir.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When site.yaml is empty" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify empty playbook should throw" {
                    { VerifyYaml -BaseYaml "$env:templatePath/empty.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When site.yaml role is missing" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify missing role playbook should throw" {
                    { VerifyYaml -BaseYaml "$env:templatePath/missingrole.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When site.yaml target invalid role name" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify invalid role playbook should throw" {
                    { VerifyYaml -BaseYaml "$env:templatePath/invalidrole.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When task file is missing" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify no task should not throw" {
                    { VerifyYaml -BaseYaml "$env:templatePath/notaskfile.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When not exists role" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "verify not exists role playbook should throw" {
                    { VerifyYaml -BaseYaml "$env:templatePath/notexistsrole.yml" -Mode $env:MODE } | Should -Throw
                }
            }
        }
    }

    foreach ($mode in "check", "run") {
        $env:Mode = $mode
        $env:templatePath = "tests/templates"
        Describe "Scoop Bucket Test (mode: $env:Mode)" {
            Context "When bucket Install" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                # NOTE: scoop 0.2.0 has bug and test will fail. see: https://github.com/ScoopInstaller/Scoop/issues/4917
                It "installing bucket should not throw" {
                    { RunMain -BaseYaml "$env:templatePath/bucket_install.yml" -Mode $env:MODE } | Should -Not -Throw
                }
                It "installing bucket extras should not throw" {
                    { RunMain -BaseYaml "$env:templatePath/bucket_install_extras.yml" -Mode $env:MODE } | Should -Not -Throw
                }
            }
            Context "When bucket Uninstall" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "uninstalling bucket should not throw" {
                    { RunMain -BaseYaml "$env:templatePath/bucket_uninstall.yml" -Mode $env:MODE } | Should -Not -Throw
                }
                It "uninstalling bucket extras should not throw" {
                    { RunMain -BaseYaml "$env:templatePath/bucket_uninstall_extras.yml" -Mode $env:MODE } | Should -Not -Throw
                }
                It "uninstall non existing bucket should not throw" {
                    { RunMain -BaseYaml "$env:templatePath/bucket_uninstall_not_exists_bucket.yml" -Mode $env:MODE } | Should -Not -Throw
                }
            }
            Context "When bucket Install invalid" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "install non existing source bucket should throw" {
                    { RunMain -BaseYaml "$env:templatePath/bucket_install_not_exists_source.yml" -Mode $env:MODE } | Should -Throw
                }
            }
        }
    }

    foreach ($mode in "check", "run") {
        $env:Mode = $mode
        $env:templatePath = "tests/templates"
        Describe "Scoop App Test (mode: $env:Mode)" {
            Context "When package is exists" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "installing package should not throw" {
                    { RunMain -BaseYaml "$env:templatePath/app_install.yml" -Mode $env:MODE } | Should -Not -Throw
                }
                It "uninstalling package should not throw" {
                    { RunMain -BaseYaml "$env:templatePath/app_uninstall.yml" -Mode $env:MODE } | Should -Not -Throw
                }
            }
            Context "When package is not exists in task" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "install non existing package should throw" {
                    { RunMain -BaseYaml "$env:templatePath/app_install_not_exists_package.yml" -Mode $env:MODE } | Should -Throw
                }
                It "uninstall non existing package should throw" {
                    { RunMain -BaseYaml "$env:templatePath/app_uninstall_not_exists_package.yml" -Mode $env:MODE } | Should -Throw
                }
            }
            Context "When task missing bucket prop" {
                BeforeEach {
                    Mock Write-Host { } -Verifiable
                }
                It "installing package should throw" {
                    { RunMain -BaseYaml "$env:templatePath/app_install_missingbucket.yml" -Mode $env:MODE } | Should -Throw
                }
                It "uninstalling package  should throw" {
                    { RunMain -BaseYaml "$env:templatePath/app_uninstall_missingbucket.yml" -Mode $env:MODE } | Should -Throw
                }
            }
        }
    }
}
Remove-Module ScoopPlaybook -Force
