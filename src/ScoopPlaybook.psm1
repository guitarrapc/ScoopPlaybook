#Requires -Version 5.1
using namespace System.Collections.Generic

# setup
Set-StrictMode -Version Latest

enum Modules {name; scoop_install; scoop_install_extras; }
enum RunMode {check; run; update_scoop; }
enum ModuleElement {name; state; }
enum StateElement {present; absent; }

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
        throw "scoop not exists in PATH!!"
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
        throw [System.IO.FileNotFoundException]::New("File not found. $BaseYaml")
    }
    
    # Handle Playbook
    $basePath = [System.IO.Path]::GetDirectoryName($BaseYaml)
    $definitions = Get-Content -LiteralPath $BaseYaml -Raw | ConvertFrom-Yaml
    if ($null -eq $definitions) {
        Write-Host "Nothing definied in $BaseYaml"
        return
    }
    $playbookName = $definitions["name"]
    $roles = $definitions["roles"].ToArray()
    if ($null -eq $roles) {
        Write-Host "No roles definied in $BaseYaml"
        return
    }

    $marker = "*" * ($lineWidth - "PLAY [$playbookName]".Length)
    Write-Host "PLAY [$playbookName] $marker"
    Write-Host ""

    # Handle Role
    foreach ($role in $roles) {
        Write-Verbose "Checking role definition from [$basePath/roles/$role/tasks/]"
        $tasks = Get-ChildItem -LiteralPath "$basePath/roles/$role/tasks/" -Include *.yml -File
        if ($null -eq $tasks) {
            continue
        }

        # Handle Task
        foreach ($task in $tasks.FullName) {
            Write-Verbose "Read from [$task]"
            $taskDef = Get-Content -LiteralPath $task -Raw | ConvertFrom-Yaml
            if ($null -eq $taskDef) {
                Write-Verbose "No valid task definied in $task"
                continue
            }
        
            # Handle Module
            foreach ($module in $taskDef) {
                $name = $module["name"]
                $module.Remove("name")

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
                    ScoopStateHandler -Module $module -Tag $tag
                }
                elseif ($containsExtraInstall) {
                    # handle scoop_install_extras
                    $tag = [Modules]::scoop_install_extras
                    if ([string]::IsNullOrWhiteSpace($name)) {
                        $name = $tag.ToString()
                    }
                    $marker = "*" * ($lineWidth - "TASK [$role : $name]".Length)
                    Write-Host "TASK [$role : $name] $marker"
                    ScoopStateHandler -Module $module -Tag $tag
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
                        return 1
                    }
                }
                Write-Host ""
            }
        }
    }
}

function ScoopStateHandler {
    [OutputType([int])]
    param(
        [HashTable]$Module,
        [Modules]$Tag
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

    switch ($state) {
        $([StateElement]::present) {
            ScoopInstall -Module $moduleDetail -Tag $tag
        }
        $([StateElement]::absent) {
            ScoopUninstall -Module $moduleDetail -Tag $tag
        }
    }
}

function ScoopInstall {
    [OutputType([int])]
    param(
        [HashTable]$Module,
        [Modules]$Tag
    )
   
    $tools = $Module[$([ModuleElement]::name.ToString())]

    # blank definition
    # hash table null should detect with string cast..... orz
    if ([string]::IsNullOrWhiteSpace($tools)) {
        Write-Verbose "Skipping, missing any tools"
        continue
    }

    foreach ($tool in $tools) {
        if ($script:modeType -eq [RunMode]::check) {
            $output = scoop info $tool
            $installed = $output | Select-String -Pattern "Installed:"
            if ($installed.Line -match "no") {
                Write-Host -ForeGroundColor Yellow "check: [${Tag}: $tool] => Require install"
                Write-Host -ForeGroundColor Yellow $installed.Line
            }
            else {
                Write-Host -ForeGroundColor Green "check: [${Tag}: $tool] => Already installed"
                Write-Verbose "$($installed.Line)$($output[$installed.LineNumber++])"
            }
        }
        else {
            $output = scoop info $tool
            $installed = $output | Select-String -Pattern "Installed:"
            if ($installed.Line -match "no") {
                Write-Host -ForegroundColor Yellow "changed: [${Tag}: $tool] => Require install"
                scoop install $tool
            }
            else {
                Write-Host -ForeGroundColor Green "ok: [${Tag}: $tool] => Already installed, checking update"
                scoop update $tool
            }
        }
    }
}

function ScoopUninstall {
    [OutputType([int])]
    param(
        [HashTable]$Module,
        [Modules]$Tag
    )

    $tools = $Module[$([ModuleElement]::name.ToString())]
    # blank definition
    if ([string]::IsNullOrWhiteSpace($tools)) {
        Write-Verbose "Skipping, missing any tools"
        continue
    }

    foreach ($tool in $tools) {
        if ($script:modeType -eq [RunMode]::check) {
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