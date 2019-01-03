$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path) -replace '\.Tests\.', '.'
. "$here\$sut"

$org = $env:PATH
$templatePath = "tests/templates"

Describe "Prerequisites not installed scoop scenario" {
    BeforeAll {
        $env:PATH = ($env:Path -split ";" -replace ".*scoop.*" | Where-Object {$_ -ne ""}) -join ";"
    }
    AfterAll {
        $env:PATH = $org
    }
    It "environment variable is mocking not to have scoop" {
        $env:PATH | Should -Not -Match "scoop"
    }
    It "throw if scoop is not found in environment variable" {
        { Prerequisites } | Should -Throw
    }
}

Describe "Prerequisites already installed scoop scenario" {
    BeforeAll {
        $env:PATH = ($env:PATH -split ";" -replace ".*scoop.*" | Where-Object {$_ -ne ""}) -join ";"
        $env:PATH = "${env:TEMP}/scoop};${env:PATH}"
    }
    AfterAll {
        $env:PATH = $org
    }
    It "environment variable is mocking to have scoop" {
        $env:PATH | Should -Match "scoop"
    }
    It "never throw if scoop is found in environment variable" {
        { Prerequisites } | Should -Not -Throw
    }
}

Describe "RuntimeCheck" {
    BeforeAll {
        $env:PATH = ($env:PATH -split ";" -replace ".*scoop.*" | Where-Object {$_ -ne ""}) -join ";"
        $env:SCOOP = "${env:TEMP}/scoop"
        $env:PATH = "${env:SCOOP}/shims;${env:PATH}"
        iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
    }
    AfterAll {
        Remove-Item -Path "${env:TEMP}/scoop" -Recurse -Force
        $env:PATH = $org
        $env:SCOOP = ""
    }
    It "custom directory installed scoop must callable" {
        { scoop } | Should -Not -Throw
    }
    It "runtime check should be pass when latest scoop installed" {
        RuntimeCheck | Should -Be $true
    }
}

Describe "RunMain : run" {
    BeforeAll {
        $env:MODE = "run"
        $env:PATH = ($env:PATH -split ";" -replace ".*scoop.*" | Where-Object {$_ -ne ""}) -join ";"
        $env:SCOOP = "${env:TEMP}/scoop"
        $env:PATH = "${env:SCOOP}/shims;${env:PATH}"
        iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
    }
    AfterAll {
        scoop uninstall time *>&1>$null
        Remove-Item -Path "${env:TEMP}/scoop" -Recurse -Force
        $env:MODE = ""
        $env:PATH = $org
        $env:SCOOP = ""
    }
    It "not existing playbook should throw" {
        { RunMain -BaseYaml "noneexitpath.yml" -Mode $env:MODE } | Should -Throw
    }
    It "verify empty playbook should not throw" {
        { RunMain -BaseYaml "$templatePath/empty.yml" -Mode $env:MODE } | Should -Not -Throw
    }
    It "verify empty playbook should return 0" {
        RunMain -BaseYaml "$templatePath/empty.yml" -Mode $env:MODE | Should -Be 0
    }
    It "verify missing role playbook should not throw" {
        RunMain -BaseYaml "$templatePath/missingrole.yml" -Mode $env:MODE | Should -Be 0
    }
    It "verify nonexisting role playbook should return 0" {
        RunMain -BaseYaml "$templatePath/fakerole.yml" -Mode $env:MODE | Should -Be 0
    }
    It "verify none existing task role should not throw" {
        { RunMain -BaseYaml "$templatePath/notask.yml" -Mode $env:MODE } | Should -Not -Throw
    }
    It "verify not valid module role should throw" {
        { RunMain -BaseYaml "$templatePath/notvalidmodule.yml" -Mode $env:MODE } | Should -Throw
    }
    It "verify nonexisting package role should throw" {
        { RunMain -BaseYaml "$templatePath/nonexistingpackage.yml" -Mode $env:MODE } | Should -Throw
    }
    It "verify check install package role should return 0" {
        { RunMain -BaseYaml "$templatePath/success.yml" -Mode $env:MODE } | Should -Not -Throw
    }
    It "installing package role should not throw" {
        { RunMain -BaseYaml "$templatePath/success.yml" -Mode $env:MODE } | Should -Not -Throw
    }
    It "run command should not throw" {
        { timecmd echo 0 } | Should -Not -Throw
    }
    It "uninstalling package role should not throw" {
        { RunMain -BaseYaml "$templatePath/uninstall.yml" -Mode $env:MODE } | Should -Not -Throw
    }
}

Describe "RunMain Guard : check" {
    BeforeAll {
        $env:MODE = "check"
        $env:PATH = ($env:PATH -split ";" -replace ".*scoop.*" | Where-Object {$_ -ne ""}) -join ";"
        $env:SCOOP = "${env:TEMP}/scoop"
        $env:PATH = "${env:SCOOP}/shims;${env:PATH}"
        iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
    }
    AfterAll {
        scoop uninstall time *>&1>$null
        Remove-Item -Path "${env:TEMP}/scoop" -Recurse -Force
        $env:MODE = ""
        $env:PATH = $org
        $env:SCOOP = ""
    }
    It "not existing yaml should throw" {
        { RunMain -BaseYaml "noneexitpath.yml" -Mode $env:MODE } | Should -Throw
    }
    It "verify empty playbook should not throw" {
        { RunMain -BaseYaml "$templatePath/empty.yml" -Mode $env:MODE } | Should -Not -Throw
    }
    It "verify empty playbook should return 0" {
        RunMain -BaseYaml "$templatePath/empty.yml" -Mode $env:MODE | Should -Be 0
    }
    It "verify missing role playbook should not throw" {
        RunMain -BaseYaml "$templatePath/missingrole.yml" -Mode $env:MODE | Should -Be 0
    }
    It "verify nonexisting role playbook should return 0" {
        RunMain -BaseYaml "$templatePath/fakerole.yml" -Mode $env:MODE | Should -Be 0
    }
    It "verify none existing task role should not throw" {
        { RunMain -BaseYaml "$templatePath/notask.yml" -Mode $env:MODE } | Should -Not -Throw
    }
    It "verify not valid module role should throw" {
        { RunMain -BaseYaml "$templatePath/notvalidmodule.yml" -Mode $env:MODE } | Should -Throw
    }
    It "verify nonexisting package role should throw" {
        { RunMain -BaseYaml "$templatePath/nonexistingpackage.yml" -Mode $env:MODE } | Should -Throw
    }
    It "verify check install package role should return 0" {
        RunMain -BaseYaml "$templatePath/success.yml" -Mode $env:MODE | Should -Be 0
    }
    It "installing package role should not throw" {
        { RunMain -BaseYaml "$templatePath/success.yml" } | Should -Not -Throw
    }
    It "verify installed package role should return 0" {
        RunMain -BaseYaml "$templatePath/success.yml" -Mode $env:MODE | Should -Be 0
    }
    It "uninstalling package role should not throw" {
        { RunMain -BaseYaml "$templatePath/uninstall.yml" -Mode $env:MODE } | Should -Not -Throw
    }
}

Describe "Invoke-ScoopPlaybook : run" {
    BeforeAll {
        $env:MODE = "run"
        $env:PATH = ($env:PATH -split ";" -replace ".*scoop.*" | Where-Object {$_ -ne ""}) -join ";"
        $env:SCOOP = "${env:TEMP}/scoop"
        $env:PATH = "${env:SCOOP}/shims;${env:PATH}"
        iex (new-object net.webclient).downloadstring('https://get.scoop.sh')
    }
    AfterAll {
        scoop uninstall time *>&1>$null
        Remove-Item -Path "${env:TEMP}/scoop" -Recurse -Force
        $env:MODE = ""
        $env:PATH = $org
        $env:SCOOP = ""
    }
    It "not existing playbook should throw" {
        { Invoke-ScoopPlaybook -LiteralPath "noneexitpath.yml" -Mode $env:MODE } | Should -Throw
    }
    It "verify empty playbook should not throw" {
        { Invoke-ScoopPlaybook -LiteralPath "$templatePath/empty.yml" -Mode $env:MODE } | Should -Not -Throw
    }
    It "verify empty playbook should return 0" {
        Invoke-ScoopPlaybook -LiteralPath "$templatePath/empty.yml" -Mode $env:MODE | Should -Be 0
    }
    It "verify missing role playbook should not throw" {
        Invoke-ScoopPlaybook -LiteralPath "$templatePath/missingrole.yml" -Mode $env:MODE | Should -Be 0
    }
    It "verify nonexisting role playbook should return 0" {
        Invoke-ScoopPlaybook -LiteralPath "$templatePath/fakerole.yml" -Mode $env:MODE | Should -Be 0
    }
    It "verify none existing task role should not throw" {
        { Invoke-ScoopPlaybook -LiteralPath "$templatePath/notask.yml" -Mode $env:MODE } | Should -Not -Throw
    }
    It "verify not valid module role should throw" {
        { Invoke-ScoopPlaybook -LiteralPath "$templatePath/notvalidmodule.yml" -Mode $env:MODE } | Should -Throw
    }
    It "verify nonexisting package role should throw" {
        { Invoke-ScoopPlaybook -LiteralPath "$templatePath/nonexistingpackage.yml" -Mode $env:MODE } | Should -Throw
    }
    It "verify check install package role should return 0" {
        { Invoke-ScoopPlaybook -LiteralPath "$templatePath/success.yml" -Mode $env:MODE } | Should -Not -Throw
    }
    It "installing package role should not throw" {
        { Invoke-ScoopPlaybook -LiteralPath "$templatePath/success.yml" -Mode $env:MODE } | Should -Not -Throw
    }
    It "run command should not throw" {
        { timecmd echo 0 } | Should -Not -Throw
    }
    It "uninstalling package role should not throw" {
        { Invoke-ScoopPlaybook -LiteralPath "$templatePath/uninstall.yml" -Mode $env:MODE } | Should -Not -Throw
    }
}

Remove-Module ScoopPlaybook -Force

