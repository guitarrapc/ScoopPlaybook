#Requires -Version 5.1
using namespace System.Collections.Generic

# setup
Set-StrictMode -Version Latest

enum PlaybookKeys { name; roles; }
enum ModuleParams { name}
enum Modules { scoop_install; scoop_install_extras; }
enum RunMode { check; run; }
enum ModuleElement { name; state; }
enum StateElement { present; absent; }

$lineWidth = 83

function Prerequisites {
    [OutputType([void])]
    param ()

    # scoop status
    $pathExists = ($env:PATH -split ";") | Where-Object {$_ -match "scoop"} | Measure-Object
    if ($pathExists.Count -eq 0) {
        throw "scoop not exists in PATH! Make sure you have installed scoop. see https://scoop.sh/"
    }
}

function RuntimeCheck {
    [OutputType([bool])]
    param (
        [bool]$UpdateScoop = $false
    )

    # scoop status check
    if ($UpdateScoop) {
        $status = scoop status *>&1
        if (!$?) {
            return $false
        }
        if ($status -match 'scoop update') {
            scoop update
        }
    }

    # check potential problem
    $result = scoop checkup *>&1
    if ($result -match "No problems") {
        return $true
    }
    else {
        return $false
    }
}

function RunMain {
    [OutputType([int])]
    param(
        [string]$BaseYaml = "site.yml",
        [RunMode]$Mode = [RunMode]::run
    )
    
    # Verify Playbook exists
    if (!(Test-Path $BaseYaml)) {
        throw [System.IO.FileNotFoundException]::New("File not found. $BaseYaml")
    }
    # Verify Playbook is not empty
    $basePath = [System.IO.Path]::GetDirectoryName($BaseYaml)
    $definitions = Get-Content -LiteralPath $BaseYaml -Raw | ConvertFrom-Yaml
    if ($null -eq $definitions) {
        Write-Host "Nothing definied in $BaseYaml"
        return 0
    }
    # Verify Playbook contains roles section
    if ($null -eq $definitions[$([PlaybookKeys]::roles.ToString())]) {
        Write-Host "No roles definied in $BaseYaml"
        return 0
    }

    # Header
    $playbookName = $definitions[$([PlaybookKeys]::name.ToString())]
    $marker = "*" * ($lineWidth - "PLAY [$playbookName]".Length)
    Write-Host "PLAY [$playbookName] $marker"
    Write-Host ""

    # Handle each role
    $roles = $definitions[$([PlaybookKeys]::roles.ToString())].ToArray()
    foreach ($role in $roles) {
        Write-Verbose "Checking role definition from [$basePath/roles/$role/tasks/]"
        $tasks = Get-ChildItem -LiteralPath "$basePath/roles/$role/tasks/" -Include *.yml -File
        if ($null -eq $tasks) {
            continue
        }

        # Handle each task
        foreach ($task in $tasks.FullName) {
            Write-Verbose "Read from [$task]"
            $taskDef = Get-Content -LiteralPath $task -Raw | ConvertFrom-Yaml
            if ($null -eq $taskDef) {
                Write-Verbose "No valid task definied in $task"
                continue
            }
        
            # Handle each module
            foreach ($module in $taskDef) {
                $name = $module[$([ModuleParams]::name.ToString())]
                $module.Remove($([ModuleParams]::name.ToString()))

                # check which module
                $containsInstall = $module.Contains([Modules]::scoop_install.ToString())
                $containsExtraInstall = $module.Contains([Modules]::scoop_install_extras.ToString())

                if ($containsInstall) {
                    # handle scoop_install
                    $tag = [Modules]::scoop_install
                    if ([string]::IsNullOrWhiteSpace($name)) {
                        $name = $tag.ToString()
                    }
                    $marker = "*" * ($lineWidth - "TASK [$role : $name]".Length)
                    Write-Host "TASK [$role : $name] $marker"
                    ScoopStateHandler -Module $module -Tag $tag -Mode $Mode
                }
                elseif ($containsExtraInstall) {
                    # handle scoop_install_extras
                    $tag = [Modules]::scoop_install_extras
                    if ([string]::IsNullOrWhiteSpace($name)) {
                        $name = $tag.ToString()
                    }
                    $marker = "*" * ($lineWidth - "TASK [$role : $name]".Length)
                    Write-Host "TASK [$role : $name] $marker"
                    ScoopStateHandler -Module $module -Tag $tag -Mode $Mode
                }
                else {
                    $marker = "*" * ($lineWidth - "skipped: TASK [$role : $name]".Length)
                    Write-Host "TASK [$role : $name] $marker"
                    if ($module.Keys.Count -eq 0) {
                        Write-Host -ForeGroundColor DarkGray "skipping, no module specified"
                        continue
                    }
                    else {    
                        throw "Invalid key spacified in module `"$($module.Keys -join ',')`""
                    }
                }
                Write-Host ""
            }
        }
    }
    return 0
}

function ScoopStateHandler {
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [HashTable]$Module,
        [Parameter(Mandatory = $true)]
        [Modules]$Tag,
        [Parameter(Mandatory = $true)]
        [RunMode]$Mode
    )

    $moduleDetail = $module["$tag"]

    # blank definition
    # hash table null should detect with string cast..... orz
    if ([string]::IsNullOrWhiteSpace($moduleDetail)) {
        Write-Verbose "no valid module defined"
        return
    }

    # pick up state and switch to install/uninstall
    $state = $moduleDetail[$([ModuleElement]::state.ToString())]
    if ($null -eq $state) {
        $state = [StateElement]::present
    }

    $dryRun = $Mode -eq [RunMode]::check
    switch ($state) {
        $([StateElement]::present) {
            ScoopInstall -Module $moduleDetail -Tag $tag -DryRun $dryRun
        }
        $([StateElement]::absent) {
            ScoopUninstall -Module $moduleDetail -Tag $tag -DryRun $dryRun
        }
    }
}

function ScoopInstall {
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [HashTable]$Module,
        [Parameter(Mandatory = $true)]
        [Modules]$Tag,
        [Parameter(Mandatory = $true)]
        [bool]$DryRun
    )
   
    $tools = $Module[$([ModuleElement]::name.ToString())]

    # blank definition
    # hash table null should detect with string cast..... orz
    if ([string]::IsNullOrWhiteSpace($tools)) {
        Write-Verbose "Skipping, missing any tools"
        continue
    }

    foreach ($tool in $tools) {
        if ($DryRun) {
            $output = scoop info $tool
            $installed = $output | Select-String -Pattern "Installed:"
            if ($installed.Line -match "no") {
                Write-Host -ForeGroundColor Yellow "check: [${Tag}: $tool] => Require install $($installed.Line)"
            }
            else {
                $outputStrict = scoop list $tool
                $installedStrictCheck = $outputStrict | Select-String -Pattern " $tool "
                if ($installedStrictCheck.Line -match "*failed") {
                    # previous installation was interupped
                    Write-Host -ForeGroundColor Red "check: [${Tag}: $tool] => Failed previous installation $($installedStrictCheck.Line)"
                }
                else {
                    Write-Host -ForeGroundColor Green "check: [${Tag}: $tool] => Already installed $($installedStrictCheck.Line)"
                    Write-Verbose "$($installed.Line)$($output[$installed.LineNumber++])"                        
                }
            }
        }
        else {
            $output = scoop info $tool
            $installed = $output | Select-String -Pattern "Installed:"
            if ($installed.Line -match "no") {
                Write-Host -ForegroundColor Yellow "changed: [${Tag}: $tool] => Require install $($installed.Line)"
                scoop install $tool
            }
            else {
                $outputStrict = scoop list $tool
                $installedStrictCheck = $outputStrict | Select-String -Pattern " $tool "
                if ($installedStrictCheck.Line -match "*failed") {
                    # previous installation was interupped
                    Write-Host -ForeGroundColor Red "reinstall: [${Tag}: $tool] => Failed previous installation, reinstall require install $($installedStrictCheck.Line)"
                    scoop uninstall $tool
                    scoop install $tool
                }
                else {
                    Write-Host -ForeGroundColor Green "ok: [${Tag}: $tool] => Already installed, checking update $($installedStrictCheck.Line)"
                    scoop update $tool *>&1 | Where-Object {$_ -notmatch "Latest versions for all apps are installed"}
                }
            }
        }
    }
}

function ScoopUninstall {
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [HashTable]$Module,
        [Parameter(Mandatory = $true)]
        [Modules]$Tag,
        [Parameter(Mandatory = $true)]
        [bool]$DryRun
    )

    $tools = $Module[$([ModuleElement]::name.ToString())]
    # blank definition
    if ([string]::IsNullOrWhiteSpace($tools)) {
        Write-Verbose "Skipping, missing any tools"
        continue
    }

    foreach ($tool in $tools) {
        if ($DryRun) {
            $output = scoop info $tool
            $installed = $output | Select-String -Pattern "Installed:"
            if ($installed.Line -match "no") {
                Write-Host -ForeGroundColor Green "check: [${Tag}: $tool] => Already uninstalled"
                Write-Verbose $installed.Line
            }
            else {
                Write-Host -ForeGroundColor Yellow "check: [${Tag}: $tool] => Require uninstall"
                Write-Host -ForeGroundColor Yellow "$($installed.Line)$($output[++$installed.LineNumber])"
            }
        }
        else {
            $output = scoop info $tool
            $installed = $output | Select-String -Pattern "Installed:"
            if ($installed.Line -match "no") {
                Write-Host -ForegroundColor Green "ok: [${Tag}: $tool] => Already uninstalled"
            }
            else {
                Write-Host -ForeGroundColor Yellow "changed: [${Tag}: $tool] => Require uninstall"
                scoop uninstall $tool
            }
        }
    }
}

function Invoke-ScoopPlaybook {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $false)]
        [Alias("FullName", "Path", "PSPath")]
        [string]$LiteralPath = "./site.yml",
        [RunMode]$Mode = [RunMode]::run
    )

    # setup
    if ($Mode -eq [RunMode]::check) {
        Write-Host -ForeGroundColor Yellow "Run with $Mode mode"
    }

    # prerequisites
    Prerequisites
    if (!$?) { return 1 }

    # update
    $updateScoop = !($Mode -eq [RunMode]::check)
    $ok = RuntimeCheck -UpdateScoop $updateScoop
    if (!$?) { return 1 }
    if (!$ok) { return 1 }

    # run
    RunMain -BaseYaml $LiteralPath -Mode $Mode
}

Set-Alias -Name Scoop-Playbook -Value Invoke-ScoopPlaybook
Export-ModuleMember -Function * -Alias Scoop-Playbook