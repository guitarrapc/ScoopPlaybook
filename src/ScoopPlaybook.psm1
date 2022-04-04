#Requires -Version 5.1
using namespace System.Collections.Generic

#region setup
$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

enum LogLevel { changed; fail; header; info; ok; skip; warning; }
enum Modules { scoop_install; scoop_bucket_install; }
enum ModuleElement { name; state; }
enum ModuleParams { name }
enum PlaybookKeys { name; roles; }
enum RunMode { check; run; }
enum ScoopVersionInfo { unkown; version_0_0_1_and_lower; version_0_1_0_or_higher }
enum StateElement { present; absent; }

$script:lineWidth = $Host.UI.RawUI.MaxWindowSize.Width
$script:updatablePackages = [List[string]]::New()
$script:failedPackages = [List[string]]::New()
$script:recapStatus = [Dictionary[string, int]]::New()
$script:scoopVersion = [ScoopVersionInfo]::unkown

#endregion

#region Scoop Command Wrapper
function ScoopCmdCheckup {
    scoop checkup *>&1
}
function ScoopCmdInfo([string]$App) {
    if ([string]::IsNullOrWhiteSpace($App)) {
        throw [System.ArgumentNullException]::New($App)
    }
    scoop info $App *>&1
}
function ScoopCmdList([string]$App) {
    if ([string]::IsNullOrWhiteSpace($App)) {
        throw [System.ArgumentNullException]::New($App)
    }
    scoop list $App *>&1
}
function ScoopCmdUpdateAll {
    scoop update *>&1
}
function ScoopCmdUpdate([string]$App) {
    if ([string]::IsNullOrWhiteSpace($App)) {
        throw [System.ArgumentNullException]::New($App)
    }
    scoop update $App *>&1
}
function ScoopCmdStatus {
    scoop status *>&1
}
#endregion

#region helper
function GetScoopVersion {
    [OutputType([ScoopVersionInfo])]
    param()

    $typeName = (scoop info git | Select-Object -first 1).GetType().FullName
    if ($typeName -eq "System.Management.Automation.PSCustomObject") {
        return [ScoopVersionInfo]::version_0_1_0_or_higher
    }
    elseif ($typeName -eq [string].FullName) {
        return [ScoopVersionInfo]::version_0_0_1_and_lower
    }
    else {
        throw [System.ArgumentOutOfRangeException]::New("$typeName")
    }
}

function InitPackages() {
    $script:lineWidth = $Host.UI.RawUI.MaxWindowSize.Width
    $script:updatablePackages.Clear()
    $script:failedPackages.Clear()
    # recap
    $script:recapStatus.Clear()
    $script:recapStatus.Add("ok", 0)
    $script:recapStatus.Add("changed", 0)
    $script:recapStatus.Add("failed", 0)
}
function RecapOk() {
    $script:recapStatus["ok"]++
}
function RecapChanged() {
    $script:recapStatus["changed"]++
}
function RecapFailed() {
    $script:recapStatus["failed"]++
}
function PrintReCap {
    PrintHeader -Message "PLAY RECAP"
    Write-Host "  ok=$($recapStatus["ok"])" -NoNewline -ForegroundColor Green
    Write-Host "  changed=$($recapStatus["changed"])" -NoNewline -ForegroundColor Yellow
    Write-Host "  failed=$($recapStatus["failed"])" -NoNewline -ForegroundColor Red
    NewLine
    NewLine
}

function CalulateSeparator {
    [OutputType([int])]
    param([string]$Message)
    $num = $script:lineWidth - $Message.Length
    if ($num -le 0) {
        return 83
    }
    return $num
}
function NewLine() {
    Write-Host ""
}
function PrintSpace() {
    Write-Host -NoNewline "  "
}
function PrintHeader([string]$Message) {
    Print -LogLevel $([LogLevel]::header) -Message "$Message"
}
function PrintInfo([string]$Message) {
    Print -LogLevel $([LogLevel]::info) -Message "$Message"
}
function PrintWarning([string]$Message) {
    Print -LogLevel $([LogLevel]::warning) -Message "$Message"
}
function PrintOk([string]$Message) {
    Print -LogLevel $([LogLevel]::ok) -Message "$Message"
}
function PrintChanged([string]$Message) {
    Print -LogLevel $([LogLevel]::changed) -Message "$Message"
}
function PrintSkip([string]$Message) {
    Print -LogLevel $([LogLevel]::skip) -Message "$Message"
}
function PrintFail([string]$Message) {
    Print -LogLevel $([LogLevel]::fail) -Message "$Message"
}
function Print([LogLevel]$LogLevel, [string]$Message) {
    switch ($LogLevel) {
        $([LogLevel]::changed) {
            Write-Host -ForegroundColor Yellow "  changed: $Message"
        }
        $([LogLevel]::fail) {
            Write-Host -ForegroundColor Red "  fail: $Message"
        }
        $([LogLevel]::header) {
            $marker = "*" * (CalulateSeparator -Message "$Message ")
            Write-Host "$Message $marker"
        }
        $([LogLevel]::info) {
            Write-Host "  info: $Message"
        }
        $([LogLevel]::ok) {
            Write-Host -ForegroundColor Green "  ok: $Message"
        }
        $([LogLevel]::skip) {
            Write-Host -ForegroundColor DarkCyan "  skipping: $Message"
        }
        $([LogLevel]::warning) {
            Write-Host -ForegroundColor Yellow -BackgroundColor Black "  warning: $Message"
        }
    }
}

function DecideBaseYaml {
    [OutputType([string])]
    param (
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath
    )

    # if .yml not found, then try .yaml
    $baseYaml = "$LiteralPath"
    $alterLiteralPath = [System.IO.Path]::ChangeExtension("$baseYaml", "yaml")
    if (!(Test-Path "$baseYaml") -and (Test-Path "$alterLiteralPath")) {
        Write-Verbose "$baseYaml not found but $alterLiteralPath found, switch to alter path."
        $baseYaml = $alterLiteralPath
    }
    return $baseYaml
}

#endregion

#region ValidateYaml

function ValidateYaml {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseYaml
    )

    PrintHeader -Message "PRE [validate YAML]"

    PrintInfo -Message "[validate] Validate YAML format."

    # Verify Playbook exists
    if (!(Test-Path $BaseYaml)) {
        throw [System.IO.FileNotFoundException]::New("File not found. $BaseYaml")
    }
    # Verify Playbook is not empty
    $definitions = Get-Content -LiteralPath $BaseYaml -Raw | ConvertFrom-Yaml
    if ($null -eq $definitions) {
        throw [System.FormatException]::New("Invalid Playbook format detected. $BaseYaml is empty.")
    }
    # Verify Playbook contains roles section
    if ($null -eq $definitions[$([PlaybookKeys]::roles.ToString())]) {
        throw [System.FormatException]::New("Invalid Playbook format detected. $BaseYaml missing role section.")
    }

    PrintOk -Message "[validate] Playbook format is valid. ($BaseYaml)"

    $basePath = [System.IO.Path]::GetDirectoryName($BaseYaml)

    # Verify role yaml is valid
    $roles = @($definitions[$([PlaybookKeys]::roles.ToString())])
    foreach ($role in $roles) {
        $taskPath = "$basePath/roles/$role/tasks/"
        $tasks = Get-ChildItem -LiteralPath "$taskPath" -File | Where-Object { $_.Extension -in @(".yml", ".yaml") }
        if ($null -eq $tasks) {
            PrintWarning -Message "[validate] No task file found, role will skip. role: $role ($taskPath)"
            continue
        }
        Write-Verbose "[validate] $(($tasks | Measure-Object).Count) tasks found. role: $role ($taskPath)"

        foreach ($task in $tasks.FullName) {
            $taskDef = Get-Content -LiteralPath "$task" -Raw | ConvertFrom-Yaml
            if ($null -eq $taskDef) {
                PrintWarning -Message "[validate] No valid task definied. task will skip. role: $role ($task)"
                continue
            }
            foreach ($modules in $taskDef) {
                # Verify any modules are defined
                $modules.Remove($([ModuleParams]::name.ToString()))
                if ($modules.Keys.Count -eq 0) {
                    throw [System.FormatException]::New("Invalid Playbook format detected. Module not found in definition. role: $role ($task)")
                }

                foreach ($key in $modules.Keys) {
                    if ([Enum]::GetValues([Modules]) -notcontains $key) {
                        throw [System.FormatException]::New("Invalid Playbook format detected. Module '$key' not found in definition. Allowed values are $([Enum]::GetValues([Modules]) -join ', ') role: $role ($task)")
                    }
                    # todo: module type check. (ConvertFrom-Yaml Deserializer is not good in PowerShell....)
                }
            }
            PrintOk -Message "[validate] Task is valid. role: $role ($task)"
        }
    }
    PrintInfo -Message "[validate] Validation passed. YAML format is valid. (May fail on Role detail)"
    NewLine
}

#endregion

#region InitializeScoop

function InitializeScoop {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [RunMode]$Mode = [RunMode]::run
    )

    $before = $pwd
    try {
        PrintHeader -Message "INIT [scoop]"
        PrintInfo -Message "[init]: run with '$Mode' mode"

        # is scoop installed?
        PrintInfo -Message "[init]: check scoop installed"
        ValidateScoopInstall

        # update scoop
        PrintInfo -Message "[init]: updating buckets"
        UpdateScoop -UpdateScoop $true

        # status check
        PrintInfo -Message "[init]: checking scoop status"
        ScoopStatus

        NewLine
    }
    finally {
        # scoop automatically change current directory to scoop path, reset to runtime executed path.
        if ($before -ne $pwd) {
            Write-Verbose "Reset current directory to module executed path."
            Set-Location -Path $before
        }
    }
}

function ValidateScoopInstall {
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
        $updates = ScoopCmdUpdateAll
        foreach ($update in $updates) {
            if ($update -match "Scoop was updated successfully") {
                PrintInfo -Message "[scoop-update]: $update"
            }
            elseif ($update -match "Updating .*") {
                PrintOk -Message "[scoop-update]: $update"
            }
            else {
                PrintChanged -Message "[scoop-update]: $update"
            }
        }
    }
}

function ScoopStatus {
    [OutputType([void])]
    param ()

    # determine current scoop version
    $script:scoopVersion = GetScoopVersion

    # scoop status check
    $status = ScoopCmdStatus
    if (!$?) {
        throw $status
    }
    $updateSection = $false
    $removeSection = $false
    $failSection = $false
    foreach ($state in $status) {
        if ($state -match "Updates are available") {
            $updateSection = $true
            $removeSection = $false
            $failSection = $false
            PrintInfo -Message "[scoop-status]: $state"
        }
        elseif ($state -match "These apps failed to install") {
            $updateSection = $false
            $removeSection = $false
            $failSection = $true
            PrintInfo -Message "[scoop-status]: $state"
        }
        elseif (($state -match "These app manifests have been removed") -or ($state -match "Missing runtime dependencies")) {
            $updateSection = $false
            $removeSection = $true
            $failSection = $false
            PrintInfo -Message "[scoop-status]: $state"
        }
        elseif ($state -match "Scoop is up to date") {
            $updateSection = $false
            $removeSection = $false
            $failSection = $false
            PrintInfo -Message "[scoop-status]: $state"
        }
        elseif ($state -match "Everything is ok") {
            $updateSection = $false
            $removeSection = $false
            $failSection = $false
            PrintInfo -Message "[scoop-status]: $state"
        }
        else {
            if ($updateSection) {
                $package = $state.ToString().Split(":")[0].Trim()
                $script:updatablePackages.Add($package)
                PrintOk -Message "[scoop-status]: (updatable) $package"
            }
            elseif ($removeSection) {
                $package = $state.ToString().Trim()
                PrintOk -Message "[scoop-status]: (removable) $package"
            }
            elseif ($failSection) {
                $package = $state.ToString().Trim()
                $script:failedPackages.Add($package)
                PrintOk -Message "[scoop-status]: (failed) $package"
            }
            else {
                PrintInfo -Message "[scoop-status]: $state"
            }
        }
    }

    # check potential problem
    $result = ScoopCmdCheckup
    if ($result -notmatch "No problems") {
        PrintInfo -Message "[scoop-checkup]: potential problems found, you may better fix them to avoid trouble."
        PrintWarning -Message $result
    }
}

#endregion

#region RunMain

function RunMain {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$BaseYaml,
        [RunMode]$Mode = [RunMode]::run
    )

    $definitions = Get-Content -LiteralPath $BaseYaml -Raw | ConvertFrom-Yaml
    $basePath = [System.IO.Path]::GetDirectoryName($BaseYaml)

    # Header
    $playbookName = $definitions[$([PlaybookKeys]::name.ToString())]
    PrintHeader -Message "PLAY [$playbookName]"
    NewLine

    # Handle each role
    $roles = @($definitions[$([PlaybookKeys]::roles.ToString())])
    foreach ($role in $roles) {
        $taskPath = "$basePath/roles/$role/tasks/"
        Write-Verbose "Checking role definition from [$taskPath]"
        $tasks = Get-ChildItem -LiteralPath "$taskPath" -File | Where-Object { $_.Extension -in @(".yml", ".yaml") }
        if ($null -eq $tasks) {
            continue
        }

        # Handle each task
        foreach ($task in $tasks.FullName) {
            Write-Verbose "Read from [$task]"
            $taskDef = Get-Content -LiteralPath $task -Raw | ConvertFrom-Yaml
            if ($null -eq $taskDef) {
                continue
            }

            # Handle modules
            foreach ($modules in $taskDef) {
                $name = $modules[$([ModuleParams]::name.ToString())]
                $modules.Remove($([ModuleParams]::name.ToString()))

                # check which module
                $containsAppInstall = $modules.Contains([Modules]::scoop_install.ToString())
                $containsBucketInstall = $modules.Contains([Modules]::scoop_bucket_install.ToString())

                if ($containsAppInstall) {
                    # handle scoop_install
                    $tag = [Modules]::scoop_install
                    if ([string]::IsNullOrWhiteSpace($name)) {
                        $name = $tag.ToString()
                    }
                    PrintHeader -Message "TASK [$role : $name]"
                    ScoopAppStateHandler -Modules $modules -Tag $tag -Mode $Mode
                }
                elseif ($containsBucketInstall) {
                    # handle scoop_bucket_install
                    $tag = [Modules]::scoop_bucket_install
                    if ([string]::IsNullOrWhiteSpace($name)) {
                        $name = $tag.ToString()
                    }
                    PrintHeader -Message "TASK [$role : $name]"
                    ScoopBucketStateHandler -Modules $modules -Tag $tag -Mode $Mode
                }
                else {
                    PrintHeader -Message "TASK [$role : $name]"
                    if ($modules.Keys.Count -eq 0) {
                        PrintWarning -Message "module not specified."
                        continue
                    }
                }
                NewLine
            }
        }
    }

    PrintReCap
}

#endregion

#region BucketInstall
function ScoopBucketStateHandler {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [HashTable]$Modules,
        [Parameter(Mandatory = $true)]
        [Modules]$Tag,
        [Parameter(Mandatory = $true)]
        [RunMode]$Mode
    )

    $module = $Modules["$Tag"]

    # blank definition
    # hack: hash table null should detect with string cast.....
    if ([string]::IsNullOrWhiteSpace($module)) {
        Write-Verbose "no valid module defined"
        return
    }

    # set default bucket
    if ($null -eq $module.bucket) {
        $module.bucket = "main"
    }
    # set default source
    if (!$module.ContainsKey("source")) {
        $module["source"] = ""
    }

    # pick up state and switch to install/uninstall
    $state = $module[$([ModuleElement]::state.ToString())]
    if ($null -eq $state) {
        $state = [StateElement]::present
    }

    $dryRun = $Mode -eq [RunMode]::check
    switch ($state) {
        $([StateElement]::present) {
            if ([string]::IsNullOrWhiteSpace($module.source)) {
                ScoopBucketInstall -Bucket $module.bucket -Tag $Tag -DryRun $dryRun
            }
            else {
                ScoopBucketInstall -Bucket $module.bucket -Source $module.source -Tag $Tag -DryRun $dryRun
            }
        }
        $([StateElement]::absent) {
            ScoopBucketUninstall -Bucket $module.bucket -Tag $Tag -DryRun $dryRun
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
        PrintChanged -Message "[${Tag}]: $Bucket => Require install ($Source)"
        if ($DryRun) { continue }
        PrintSpace
        scoop bucket add "$Bucket" "$Source"
        RecapChanged
    }
    else {
        PrintOk -Message "[${Tag}]: $Bucket"
        RecapOk
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
        PrintChanged -Message "[${Tag}]: $Bucket => Require uninstall"
        if ($DryRun) { continue }
        PrintSpace
        scoop bucket rm $Bucket
        RecapChanged
    }
    else {
        PrintOk -Message "[${Tag}]: $Bucket"
        RecapOk
    }
}

#endregion

#region AppInstall

function ScoopAppStateHandler {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [HashTable]$Modules,
        [Parameter(Mandatory = $true)]
        [Modules]$Tag,
        [Parameter(Mandatory = $true)]
        [RunMode]$Mode
    )

    $module = $Modules["$Tag"]

    # blank definition
    # hack: hash table null should detect with string cast.....
    if ([string]::IsNullOrWhiteSpace($module)) {
        Write-Verbose "no valid module defined"
        return
    }

    # install bucket
    if ($null -eq $module.bucket) {
        $module.bucket = "main"
    }
    if (!(ScoopBucketExists -Bucket $module.bucket)) {
        throw "erro: [${Tag}]: $($module.bucket) => no matching bucket found."
    }

    # pick up state and switch to install/uninstall
    $state = $module[$([ModuleElement]::state.ToString())]
    if ($null -eq $state) {
        $state = [StateElement]::present
    }

    $dryRun = $Mode -eq [RunMode]::check
    $tools = $module[$([ModuleElement]::name.ToString())]
    switch ($state) {
        $([StateElement]::present) {
            ScoopAppInstall -Tools $tools -Tag $Tag -DryRun $dryRun
        }
        $([StateElement]::absent) {
            ScoopAppUninstall -Tools $tools -Tag $Tag -DryRun $dryRun
        }
    }
}

function ScoopAppInstall {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Tools,
        [Parameter(Mandatory = $true)]
        [Modules]$Tag,
        [Parameter(Mandatory = $true)]
        [bool]$DryRun
    )

    foreach ($tool in $Tools) {
        $output = ScoopCmdInfo -App $tool
        # may be typo manifest should throw fast
        if ($output -match "Could not find manifest for") {
            PrintFail -Message "[${Tag}]: $tool => $($output)"
            RecapFailed
            continue
        }
        # successfully found manifest
        $isFailedPackage = $script:failedPackages -contains $tool
        $notInstallStatus = ""
        if ($isFailedPackage) {
            $notInstallStatus = "(Failed previous installation, begin reinstall.)"
        }
        $installed = $output | Select-String -Pattern "Installed:"
        if ($installed.Line -match "no") {
            PrintChanged -Message "[${Tag}]: $tool => Require install $notInstallStatus"
            if ($DryRun) { continue }
            PrintSpace
            if ($isFailedPackage) {
                scoop uninstall $tool
                PrintSpace
            }
            scoop install $tool
            RecapChanged
        }
        else {
            $outputStrict = ScoopCmdList -App $tool
            $installedStrictCheck = $outputStrict | Select-String -Pattern "failed"
            if ($null -ne $installedStrictCheck) {
                # previous installation was interupped
                $packageInfo = $outputStrict | Select-Object -Skip 2 -First 1
                PrintChanged -Message "[${Tag}]: $tool => $($packageInfo) $notInstallStatus"
                if ($DryRun) { continue }
                PrintSpace
                if ($isFailedPackage) {
                    scoop uninstall $tool
                    PrintSpace
                }
                scoop install $tool
                RecapChanged
            }
            else {
                $isUpdatable = $updatablePackages -contains $tool
                $packageInfo = $outputStrict | Select-Object -Skip 2 -First 1
                if (!$isUpdatable) {
                    PrintOk -Message "[${Tag}]: $tool => $($packageInfo) (status: latest)"
                    RecapOk
                }
                else {
                    PrintChanged -Message "[${Tag}]: $tool => $($packageInfo) (status: updatable)"
                    if ($DryRun) { continue }
                    PrintSpace
                    ScoopCmdUpdate -App $tool | ForEach-Object { PrintInfo -Message $_ }
                    RecapChanged
                }
            }
        }
    }
}

function ScoopAppUninstall {
    [OutputType([void])]
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
        $output = ScoopCmdInfo -App $tool
        $installed = $output | Select-String -Pattern "Installed:"
        if ($null -eq $installed) {
            PrintFail -Message "[${Tag}]: $tool => $output"
            RecapFailed
            continue
        }

        if ($installed.Line -match "no") {
            PrintOk -Message "[${Tag}]: $tool => Already uninstalled"
            Write-Verbose $installed.Line
            RecapOk
        }
        else {
            PrintChanged -Message "[${Tag}]: $tool => Require uninstall"
            Write-Verbose $installed.Line
            if ($DryRun) { continue }
            scoop uninstall $tool | Out-String -Stream | ForEach-Object { Write-Host "  $_" }
            RecapChanged
        }
    }
}

#endregion

function Invoke-ScoopPlaybook {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $false)]
        [Alias("FullName", "Path", "PSPath")]
        [string]$LiteralPath = "./site.yml",
        [RunMode]$Mode = [RunMode]::run
    )

    InitPackages
    $baseYaml = DecideBaseYaml -LiteralPath "$LiteralPath"

    try {
        NewLine
        ValidateYaml -BaseYaml "$baseYaml"
        InitializeScoop -Mode $Mode
        RunMain -BaseYaml "$baseYaml" -Mode $Mode
    }
    catch [Exception] {
        PrintFail -Message "ScriptStackTrace Detail: $($_.GetType()) $($_.ScriptStackTrace)"
        throw
    }
}

Set-Alias -Name Scoop-Playbook -Value Invoke-ScoopPlaybook
Export-ModuleMember -Function * -Alias Scoop-Playbook
