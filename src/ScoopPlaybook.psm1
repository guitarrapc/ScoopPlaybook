#Requires -Version 5.1
using namespace System.Collections.Generic

# setup
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

enum PlaybookKeys { name; roles; }
enum ModuleParams { name }
enum Modules { scoop_install; scoop_bucket_install; }
enum RunMode { check; run; }
enum ModuleElement { name; state; }
enum StateElement { present; absent; }

$script:lineWidth = 83
$script:updatablePackages = [List[string]]::New()

function Prerequisites {
    [OutputType([void])]
    param ()

    # scoop status
    $pathExists = ($env:PATH -split ";") | Where-Object { $_ -match "scoop" } | Measure-Object
    if ($pathExists.Count -eq 0) {
        throw "scoop not exists in PATH! Make sure you have installed scoop. see https://scoop.sh/"
    }
}

function UpdateScoop {
    [OutputType([void])]
    param (
        [bool]$UpdateScoop = $false
    )

    # update scoop to latest status
    if ($UpdateScoop) {
        $updates = scoop update *>&1
        foreach ($update in $updates) {
            if ($update -match "Scoop was updated successfully") {
                Write-Host "  [o] check: [scoop-update: $update]" -ForegroundColor Green
            } elseif ($update -match "Updating .*") {
                Write-Host "  [o] check: [scoop-update: $update]" -ForegroundColor DarkCyan
            } else {
                Write-Host "  [o] check: [scoop-update: $update]" -ForegroundColor Yellow
            }
        }
    }
}

function RuntimeCheck {
    [OutputType([void])]
    param ()

    # scoop status check
    $status = scoop status *>&1
    if (!$?) {
        throw $status
    }
    $updateSection = $false
    $removeSection = $false
    foreach ($state in $status) {
        if ($state -match "Updates are available") {
            $updateSection = $true
            $removeSection = $false
            Write-Host "  [o] check: [scoop-status: $state]" -ForegroundColor Yellow
        }
        elseif (($state -match "These app manifests have been removed") -or ($state -match "Missing runtime dependencies")) {
            $updateSection = $false
            $removeSection = $true
            Write-Host "  [o] check: [scoop-status: $state]" -ForegroundColor Yellow
        }
        elseif ($state -match "Scoop is up to date") {
            $updateSection = $false
            $removeSection = $false
            Write-Host "  [o] skip: [scoop-status: $state]" -ForegroundColor Green
        }
        else {
            if ($updateSection) {
                $package = $state.ToString().Split(":")[0].Trim()
                $script:updatablePackages.Add($package)
                Write-Host "  [!] check: [scoop-status: (updatable) $package]" -ForegroundColor DarkCyan
            }
            elseif ($removeSection) {
                $package = $state.ToString().Trim()
                Write-Host "  [!] check: [scoop-status: (removable) $package]" -ForegroundColor DarkCyan
            }
            else {
                Write-Host "  [o] skip: [scoop-status: $state]" -ForegroundColor Green
            }
        } 
    }

    # check potential problem
    $result = scoop checkup *>&1
    if ($result -notmatch "No problems") {
        throw $result
    }
}

function RunMain {
    [CmdletBinding()]
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
        return
    }
    # Verify Playbook contains roles section
    if ($null -eq $definitions[$([PlaybookKeys]::roles.ToString())]) {
        Write-Host "No roles definied in $BaseYaml"
        return
    }

    # Header
    $playbookName = $definitions[$([PlaybookKeys]::name.ToString())]
    $marker = "*" * ($script:lineWidth - "PLAY [$playbookName]".Length)
    Write-Host "PLAY [$playbookName] $marker"
    Write-Host ""

    # Handle each role
    $roles = @($definitions[$([PlaybookKeys]::roles.ToString())])
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
                $containsBucketInstall = $module.Contains([Modules]::scoop_bucket_install.ToString())

                if ($containsInstall) {
                    # handle scoop_install
                    $tag = [Modules]::scoop_install
                    if ([string]::IsNullOrWhiteSpace($name)) {
                        $name = $tag.ToString()
                    }
                    $marker = "*" * ($script:lineWidth - "TASK [$role : $name]".Length)
                    Write-Host "TASK [$role : $name] $marker"
                    ScoopModuleStateHandler -Module $module -Tag $tag -Mode $Mode
                }
                elseif ($containsBucketInstall) {
                    # handle scoop_bucket_install
                    $tag = [Modules]::scoop_bucket_install
                    if ([string]::IsNullOrWhiteSpace($name)) {
                        $name = $tag.ToString()
                    }
                    $marker = "*" * ($script:lineWidth - "TASK [$role : $name]".Length)
                    Write-Host "TASK [$role : $name] $marker"
                    ScoopBucketStateHandler -Module $module -Tag $tag -Mode $Mode
                }
                else {
                    $marker = "*" * ($script:lineWidth - "skipped: TASK [$role : $name]".Length)
                    Write-Host "TASK [$role : $name] $marker"
                    if ($module.Keys.Count -eq 0) {
                        Write-Host -ForeGroundColor DarkGray "skipping, no module specified"
                        continue
                    }
                    else {
                        throw "error: Invalid key spacified in module `"$($module.Keys -join ',')`""
                    }
                }
                Write-Host ""
            }
        }
    }
    return
}

function ScoopBucketStateHandler {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [HashTable]$Module,
        [Parameter(Mandatory = $true)]
        [Modules]$Tag,
        [Parameter(Mandatory = $true)]
        [RunMode]$Mode
    )

    $moduleDetail = $Module["$Tag"]

    # blank definition
    # hash table null should detect with string cast..... orz
    if ([string]::IsNullOrWhiteSpace($moduleDetail)) {
        Write-Verbose "no valid module defined"
        return
    }

    # set default bucket
    if ($null -eq $moduleDetail.bucket) {
        $moduleDetail.bucket = "main"
    }
    # set default source
    if (!$moduleDetail.ContainsKey("source")) {
        $moduleDetail["source"] = ""
    }
    
    # pick up state and switch to install/uninstall
    $state = $moduleDetail[$([ModuleElement]::state.ToString())]
    if ($null -eq $state) {
        $state = [StateElement]::present
    }

    $dryRun = $Mode -eq [RunMode]::check
    switch ($state) {
        $([StateElement]::present) {
            if ([string]::IsNullOrWhiteSpace($moduleDetail.source)) {
                ScoopBucketInstall -Bucket $moduleDetail.bucket -Tag $Tag -DryRun $dryRun
            }
            else {
                ScoopBucketInstall -Bucket $moduleDetail.bucket -Source $moduleDetail.source -Tag $Tag -DryRun $dryRun
            }
        }
        $([StateElement]::absent) {
            ScoopBucketUninstall -Bucket $moduleDetail.bucket -Tag $Tag -DryRun $dryRun
        }
    }
}

function ScoopModuleStateHandler {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [HashTable]$Module,
        [Parameter(Mandatory = $true)]
        [Modules]$Tag,
        [Parameter(Mandatory = $true)]
        [RunMode]$Mode
    )

    $moduleDetail = $Module["$Tag"]

    # blank definition
    # hash table null should detect with string cast..... orz
    if ([string]::IsNullOrWhiteSpace($moduleDetail)) {
        Write-Verbose "no valid module defined"
        return
    }

    # install bucket
    if ($null -eq $moduleDetail.bucket) {
        $moduleDetail.bucket = "main"
    }
    if (!(ScoopBucketExists -Bucket $moduleDetail.bucket)) {
        throw "error: [${Tag}: $($moduleDetail.bucket)] => no matching bucket found."
    }
    
    # pick up state and switch to install/uninstall
    $state = $moduleDetail[$([ModuleElement]::state.ToString())]
    if ($null -eq $state) {
        $state = [StateElement]::present
    }

    $dryRun = $Mode -eq [RunMode]::check
    $tools = $moduleDetail[$([ModuleElement]::name.ToString())]
    switch ($state) {
        $([StateElement]::present) {
            ScoopInstall -Tools $tools -Tag $Tag -DryRun $dryRun
        }
        $([StateElement]::absent) {
            ScoopUninstall -Tools $tools -Tag $Tag -DryRun $dryRun
        }
    }
}

function ScoopBucketExists {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Bucket
    )

    $buckets = scoop bucket list
    return ($null -ne $buckets) -and ($buckets -match $Bucket)
}

function ScoopBucketInstall {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Bucket,
        [Parameter(Mandatory = $false)]
        [string]$Source,
        [Parameter(Mandatory = $true)]
        [Modules]$Tag,
        [Parameter(Mandatory = $true)]
        [bool]$DryRun
    )

    if (!(ScoopBucketExists -Bucket $Bucket)) {
        if ($DryRun) {
            Write-Host -ForeGroundColor Yellow "  [!] check: [${Tag}: $Bucket] => $Source (installed: $false)"
        }
        else {
            Write-Host -ForegroundColor Yellow "  [!] changed: [${Tag}: $Bucket] => $Source (installed: $false)"
            Write-Host "  " -NoNewline
            scoop bucket add $Bucket $Source
        }
    }
    else {
        Write-Host -ForeGroundColor Green "  [o] skip: [${Tag}: $Bucket]"
    }
}

function ScoopBucketUninstall {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Bucket,
        [Parameter(Mandatory = $true)]
        [Modules]$Tag,
        [Parameter(Mandatory = $true)]
        [bool]$DryRun
    )

    if (ScoopBucketExists -Bucket $Bucket) {
        if ($DryRun) {
            Write-Host -ForeGroundColor Yellow "  [!] check: [${Tag}: $Bucket] (installed: $false)"
        }
        else {
            Write-Host -ForegroundColor Yellow "  [!] changed: [${Tag}: $Bucket] (installed: $false)"
            Write-Host "  " -NoNewline
            scoop bucket rm $Bucket
        }
    }
    else {
        Write-Host -ForeGroundColor Green "  [o] skip: [${Tag}: $Bucket]"
    }
}

function ScoopInstall {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Tools,
        [Parameter(Mandatory = $true)]
        [Modules]$Tag,
        [Parameter(Mandatory = $true)]
        [bool]$DryRun
    )
   
    foreach ($tool in $Tools) {
        if ($DryRun) {
            $output = scoop info $tool *>&1
            # may be typo manifest should throw fast
            if ($output -match "Could not find manifest for") {
                Write-Host -ForegroundColor Red "  [x] failed: [${Tag}: $tool] => $($output)"
                throw "ACTION: please make sure your desired manifest '$tool' is available."
            }
            # successfully found manifest
            $installed = $output | Select-String -Pattern "Installed:"
            if ($installed.Line -match "no") {
                Write-Host -ForeGroundColor Yellow "  [!] check: [${Tag}: $tool] => $($installed.Line)"
            }
            else {
                $outputStrict = scoop list $tool *>&1
                $installedStrictCheck = $outputStrict | Select-String -Pattern "failed"
                if ($null -ne $installedStrictCheck) {
                    # previous installation was interupped
                    Write-Host -ForeGroundColor Yellow "  [!] check: [${Tag}: $tool] => $($outputStrict | Select-Object -Skip 1 -First 2) (installed: $false, Failed previous installation, begin reinstall.)"
                }
                else {
                    $isUpdatable = $updatablePackages -contains $tool
                    if (!$isUpdatable) {
                        Write-Host -ForeGroundColor Green "  [o] skip: [${Tag}: $tool] => $($outputStrict | Select-Object -Skip 1 -First 2)"
                    }
                    else {
                        Write-Host -ForeGroundColor DarkCyan "  [!] check: [${Tag}: $tool] => $($outputStrict | Select-Object -Skip 1 -First 2) (updatable: $isUpdatable)"
                    }
                    Write-Verbose "$($installed.Line)$($output[$installed.LineNumber++])"                        
                }
            }
        }
        else {
            $output = scoop info $tool *>&1
            # may be typo manifest should throw fast
            if ($output -match "Could not find manifest for") {
                Write-Host -ForegroundColor Red "  [x] failed: [${Tag}: $tool] => $($output)"
                throw "ACTION: please make sure your desired manifest '$tool' is available."
            }
            # successfully found manifest
            $installed = $output | Select-String -Pattern "Installed:"
            if ($installed.Line -match "no") {
                Write-Host -ForegroundColor Yellow "  [!] changed: [${Tag}: $tool] => $($installed.Line)"
                Write-Host "  " -NoNewline
                scoop install $tool
            }
            else {
                $outputStrict = scoop list $tool *>&1
                $installedStrictCheck = $outputStrict | Select-String -Pattern "failed"
                if ($null -ne $installedStrictCheck) {
                    # previous installation was interupped
                    Write-Host -ForeGroundColor Yellow "  [!] changed: [${Tag}: $tool] => $($outputStrict | Select-Object -Skip 1 -First 2) (installed: $false, Failed previous installation, begin reinstall.)"
                    Write-Host "  " -NoNewline
                    scoop uninstall $tool
                    Write-Host "  " -NoNewline
                    scoop install $tool
                }
                else {
                    $isUpdatable = $updatablePackages -contains $tool
                    if (!$isUpdatable) {
                        Write-Host -ForeGroundColor Green "  [o] skip: [${Tag}: $tool] => $($outputStrict | Select-Object -Skip 1 -First 2)"
                    }
                    else {
                        Write-Host -ForeGroundColor DarkCyan "  [!] update: [${Tag}: $tool] => $($outputStrict | Select-Object -Skip 1 -First 2) (updatable: $isUpdatable)"
                        Write-Host "  " -NoNewline
                        scoop update $tool *>&1 | Foreach-Object { Write-Host $_ }                        
                    }
                }
            }
        }
    }
}

function ScoopUninstall {
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Tools,
        [Parameter(Mandatory = $true)]
        [Modules]$Tag,
        [Parameter(Mandatory = $true)]
        [bool]$DryRun
    )

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
                Write-Host -ForeGroundColor Green "  [o] skip: [${Tag}: $tool] => Already uninstalled"
                Write-Verbose $installed.Line
            }
            else {
                Write-Host -ForeGroundColor Yellow "  [!] check: [${Tag}: $tool] => Require uninstall"
                Write-Host -ForeGroundColor Yellow "$($installed.Line)$($output[++$installed.LineNumber])"
            }
        }
        else {
            $output = scoop info $tool
            $installed = $output | Select-String -Pattern "Installed:"
            if ($installed.Line -match "no") {
                Write-Host -ForegroundColor Green "  [o] skip: [${Tag}: $tool] => Already uninstalled"
            }
            else {
                Write-Host -ForeGroundColor Yellow "  [!] changed: [${Tag}: $tool] => Require uninstall"
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

    $before = $pwd
    try {
        # setup
        $marker = "*" * ($script:lineWidth - "PRE [scoop : status]".Length)
        if ($Mode -eq [RunMode]::check) {
            $boxMark = "o"
            $task = "skip"
            $color = "Green"
        }
        else {
            $boxMark = "!"
            $task = "check"
            $color = "Yellow"
        }
        Write-Host "PRE [scoop : status] $marker"
        Write-Host -ForeGroundColor $color "  [$boxMark] ${task}: [run with '$Mode' mode]"

        # prerequisites
        Write-Host -ForeGroundColor $color "  [$boxMark] ${task}: [prerequisiting availability]"
        Prerequisites

        # update
        Write-Host -ForeGroundColor $color "  [$boxMark] ${task}: [updating buckets]"
        UpdateScoop -UpdateScoop $true

        # status check
        Write-Host -ForeGroundColor $color "  [$boxMark] ${task}: [status checking]"
        $ok = RuntimeCheck
    }
    finally {
        # scoop automatically change current directory to scoop path, revert to runtime executed path.
        if ($before -ne $pwd) {
            Write-Verbose "Revert current directory to module executed path."
            Set-Location -Path $before
        }
    }

    # run
    try {
        RunMain -BaseYaml $LiteralPath -Mode $Mode
    }
    catch [Exception] {
        Write-Host -ForeGroundColor Yellow "ScriptStackTrace Detail: $($_.GetType()) $($_.ScriptStackTrace)"
        throw
    }
}

Set-Alias -Name Scoop-Playbook -Value Invoke-ScoopPlaybook
Export-ModuleMember -Function * -Alias Scoop-Playbook