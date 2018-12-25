#Requires -Version 5.1
using namespace System.Collections.Generic

# setup
Set-StrictMode -Version Latest

enum Keywords {name; scoop_install; scoop_uninstall; scoop_install_extras; }
enum RunMode {check; run; update_scoop; }

[RunMode]$script:modeType = [RunMode]::run
$lineWidth = 83

function Prerequisites {
    [OutputType([bool])]
    param ()

    # scoop status
    $pathExists = ($env:PATH -split ";") | Where-Object {$_ -match "scoop"} | Measure-Object
    if ($pathExists.Count -gt 0) {
        return $true
    }
    else {
        Write-Error "scoop not exists in PATH!!"
        return $false
    }
    
    # status
    scoop status
    if (!$?) {
        return $false
    }

    # check potential problem
    scoop checkup
}

function RunMain {
    [OutputType([int])]
    param(
        [string]$BaseYaml = "site.yml"
    )
    
    if (!(Test-Path $BaseYaml)) {
        return 1
    }
    $basePath = [System.IO.Path]::GetDirectoryName($BaseYaml)
    $definitions = Get-Content -LiteralPath $BaseYaml -Raw | ConvertFrom-Yaml
    if ($null -eq $definitions) {
        Write-Host "Nothing definied in $BaseYaml"
        return 1
    }
    $playbookName = $definitions["name"]
    $roles = $definitions["roles"].ToArray()
    if ($null -eq $roles) {
        Write-Host "No roles definied in $BaseYaml"
        return 1
    }

    # BaseYaml's role existstance check
    $marker = "*" * ($lineWidth - "PLAY [$playbookName]".Length)
    Write-Host "PLAY [$playbookName] $marker"
    Write-Host ""
    foreach ($item in $roles) {
        Write-Verbose "Checking role definition from [$basePath/roles/$item/tasks/]"
        $tasks = Get-ChildItem -LiteralPath "$basePath/roles/$item/tasks/" -Include *.yml -File
        if ($null -eq $tasks) {
            continue
        }

        # role's Task check and run
        foreach ($task in $tasks.FullName) {
            Write-Verbose "Read from [$task]"
            $taskDef = Get-Content -LiteralPath $task -Raw | ConvertFrom-Yaml

            # role
            foreach ($def in $taskDef) {
                $name = $def.name
                # task contains "scoop_install" check
                $containsInstall = $def.Contains([Keywords]::scoop_install.ToString())
                # task contains "scoop_uninstall" check
                $containsUninstall = $def.Contains([Keywords]::scoop_uninstall.ToString())
                # task contains "scoop_install_extras" check
                $containsExtraInstall = $def.Contains([Keywords]::scoop_install_extras.ToString())

                if ($containsInstall) {
                    $marker = "*" * ($lineWidth - "TASK [$item : $name]".Length)
                    Write-Host "TASK [$item : $name] $marker"
                    ScoopInstall -TaskDef $def -Tag ([Keywords]::scoop_install)
                }
                elseif ($containsUninstall) {
                    $marker = "*" * ($lineWidth - "TASK [$item : $name]".Length)
                    Write-Host "TASK [$item : $name] $marker"
                    ScoopUninstall -TaskDef $def -Tag ([Keywords]::scoop_uninstall)
                }
                elseif ($containsExtraInstall) {
                    $marker = "*" * ($lineWidth - "TASK [$item : $name]".Length)
                    Write-Host "TASK [$item : $name] $marker"
                    scoop bucket add extras
                    ScoopInstall -TaskDef $def -Tag ([Keywords]::scoop_install_extras)
                }
                else {
                    $marker = "*" * ($lineWidth - "skipped: TASK [$item : $name]".Length)
                    Write-Host DarkCyan "skipped: TASK [$item : $name] $marker"
                    continue
                }
                Write-Host ""
            }
        }
    }
}

function ScoopInstall {
    [OutputType([int])]
    param(
        [HashTable]$TaskDef,
        [Keywords]$Tag
    )

    $tools = $TaskDef["$Tag"]
    if ($null -eq $tools) {
        return
    }

    foreach ($tool in $tools) {
        # blank definition
        if ([string]::IsNullOrWhiteSpace($tool)) {
            continue
        }

        if ($script:modeType -eq [RunMode]::check) {
            $output = scoop info $tool
            $installed = $output | Select-String -Pattern "Installed:"
            if ($installed.Line -match "no") {
                Write-Host -ForeGroundColor Yellow "check: [${Tag}: $tool]"
                Write-Host -ForeGroundColor Yellow $installed.Line
            }
            else {
                Write-Host -ForeGroundColor Green "check: [${Tag}: $tool]"
                Write-Verbose "$($installed.Line)$($output[$installed.LineNumber++])"
            }
        }
        else {
            $output = scoop info $tool
            $installed = $output | Select-String -Pattern "Installed:"
            if ($installed.Line -match "no") {
                Write-Host -ForegroundColor Yellow "changed: [$([Keywords]::scoop_install): $tool]"
                scoop install $tool
            }
            else {
                Write-Host -ForeGroundColor Green "ok: [$([Keywords]::scoop_install): $tool]"
                scoop update $tool
            }
        }
    }
}

function ScoopUninstall {
    [OutputType([int])]
    param(
        [HashTable]$TaskDef,
        [Keywords]$Tag
    )

    $tools = $TaskDef["$Tag"]
    if ($null -eq $tools) {
        return
    }

    foreach ($tool in $tools) {
        # blank definition
        if ([string]::IsNullOrWhiteSpace($tool)) {
            continue
        }

        if ($script:modeType -eq [RunMode]::check) {
            $output = scoop info $tool
            $installed = $output | Select-String -Pattern "Installed:"
            if ($installed.Line -match "no") {
                Write-Host -ForeGroundColor Green "check: [${Tag}: $tool]"
                Write-Verbose $installed.Line
            }
            else {
                Write-Host -ForeGroundColor Yellow "check: [${Tag}: $tool]"
                Write-Host -ForeGroundColor Yellow "$($installed.Line)$($output[$installed.LineNumber++])"
            }
        }
        else {
            Write-Host -ForegroundColor Yellow "changed: [${Tag}: $tool]"
            scoop uninstall $tool
        }
    }
}

function Invoke-ScoopPlaybook {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $false)]
        [Alias("FullName", "Path", "PSPath")]
        $LiteralPath = "./site.yml",

        [ValidateSet("run", "check", "update_scoop")]
        [RunMode]$Mode = [RunMode]::run
    )

    # setup
    $script:modeType = $Mode
    if ($script:modeType -eq [RunMode]::check) {
        Write-Host -ForeGroundColor Yellow "Run with $Mode mode"
    }

    # prerequisites
    if ($Mode -eq [RunMode]::update_scoop.ToString()) {
        scoop update
    }
    else {
        $ok = Prerequisites
        if (!$?) { return 1 }
        if (!$ok) { return 1 }
    
        # run
        RunMain -BaseYaml $LiteralPath
    }
}

Set-Alias -Name Scoop-Playbook -Value Invoke-ScoopPlaybook
Export-ModuleMember -Function Invoke-ScoopPlaybook -Alias Scoop-Playbook