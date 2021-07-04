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

#$script:lineWidth = $Host.UI.RawUI.MaxWindowSize.Width - $PWD.Path.Length
$script:lineWidth = $Host.UI.RawUI.MaxWindowSize.Width
$script:updatablePackages = [List[string]]::New()

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
function PrintInfo([string]$Message) {
    Write-Host "$Message"
}
function PrintWarning([string]$Message) {
    Write-Warning "$Message"
}
function PrintSkip([string]$Message) {
    Write-Host -ForegroundColor Green "$Message"
}
function PrintChanged([string]$Message) {
    Write-Host -ForegroundColor DarkCyan "$Message"
}
function PrintCheck([string]$Message) {
    Write-Host -ForegroundColor Yellow "$Message"
}
function PrintFail([string]$Message) {
    Write-Host -ForegroundColor Red "$Message"
}

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
                PrintInfo -Message "  [o] skip: [scoop-update: $update]"
            }
            elseif ($update -match "Updating .*") {
                PrintChanged -Message "  [o] chng: [scoop-update: $update]"
            }
            else {
                PrintCheck -Message "  [o] chck: [scoop-update: $update]"
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
            PrintCheck -Message "  [!] chck: [scoop-status: $state]"
        }
        elseif (($state -match "These app manifests have been removed") -or ($state -match "Missing runtime dependencies")) {
            $updateSection = $false
            $removeSection = $true
            PrintCheck -Message "  [!] chck: [scoop-status: $state]"
        }
        elseif ($state -match "Scoop is up to date") {
            $updateSection = $false
            $removeSection = $false
            PrintInfo -Message "  [o] info: [scoop-status: $state]"
        }
        else {
            if ($updateSection) {
                $package = $state.ToString().Split(":")[0].Trim()
                $script:updatablePackages.Add($package)
                PrintChanged -Message "  [!] chck: [scoop-status: (updatable) $package]"
            }
            elseif ($removeSection) {
                $package = $state.ToString().Trim()
                PrintChanged -Message "  [!] info: [scoop-status: (removable) $package]"
            }
            else {
                PrintInfo -Message "  [o] info: [scoop-status: $state]"
            }
        }
    }

    # check potential problem
    $result = scoop checkup *>&1
    if ($result -notmatch "No problems") {
        PrintCheck -Message "  [!] chck: [scoop-status: 'scoop checkup' shows potential problems, you should fix them to avoid trouble.]"
        PrintWarning -Message $result
    }
}

function VerifyYaml {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [string]$BaseYaml = "site.yml"
    )

    Write-Verbose "Validate YAML format."

    # Verify Playbook exists
    if (!(Test-Path $BaseYaml)) {
        throw [System.IO.FileNotFoundException]::New("File not found. $BaseYaml")
    }
    # Verify Playbook is not empty
    $definitions = Get-Content -LiteralPath $BaseYaml -Raw | ConvertFrom-Yaml
    if ($null -eq $definitions) {
        throw [System.FormatException]::New("Playbook format invalid. Nothing definied in $BaseYaml")
    }
    # Verify Playbook contains roles section
    if ($null -eq $definitions[$([PlaybookKeys]::roles.ToString())]) {
        throw [System.FormatException]::New("Playbook format invalid. No roles definied in $BaseYaml")
    }

    $basePath = [System.IO.Path]::GetDirectoryName($BaseYaml)

    # Verify role yaml is valid
    $roles = @($definitions[$([PlaybookKeys]::roles.ToString())])
    foreach ($role in $roles) {
        $taskPath = "$basePath/roles/$role/tasks/"
        $tasks = Get-ChildItem -LiteralPath "$taskPath" -File | Where-Object { $_.Extension -in @(".yml", ".yaml") }
        if ($null -eq $tasks) {
            PrintWarning -Message "No task file found in $taskPath"
            continue
        }

        foreach ($task in $tasks.FullName) {
            $taskDef = Get-Content -LiteralPath "$task" -Raw | ConvertFrom-Yaml
            if ($null -eq $taskDef) {
                PrintWarning -Message "No valid task definied in $task"
                continue
            }
        }
    }

    Write-Verbose "Validation passed. YAML format is valid."
}

function RunMain {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [string]$BaseYaml = "site.yml",
        [RunMode]$Mode = [RunMode]::run
    )

    $definitions = Get-Content -LiteralPath $BaseYaml -Raw | ConvertFrom-Yaml
    $basePath = [System.IO.Path]::GetDirectoryName($BaseYaml)

    # Header
    $playbookName = $definitions[$([PlaybookKeys]::name.ToString())]
    $header = "PLAY [$playbookName]"
    $marker = "*" * (CalulateSeparator -Message "$header ")
    PrintInfo -Message "$header $marker"
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

            # Handle each module
            foreach ($module in $taskDef) {
                $name = $module[$([ModuleParams]::name.ToString())]
                $module.Remove($([ModuleParams]::name.ToString()))

                # check which module
                $containsAppInstall = $module.Contains([Modules]::scoop_install.ToString())
                $containsBucketInstall = $module.Contains([Modules]::scoop_bucket_install.ToString())

                if ($containsAppInstall) {
                    # handle scoop_install
                    $tag = [Modules]::scoop_install
                    if ([string]::IsNullOrWhiteSpace($name)) {
                        $name = $tag.ToString()
                    }
                    $header = "TASK [$role : $name]"
                    $marker = "*" * (CalulateSeparator -Message "$header ")
                    PrintInfo -Message "$header $marker"
                    ScoopAppStateHandler -Module $module -Tag $tag -Mode $Mode
                }
                elseif ($containsBucketInstall) {
                    # handle scoop_bucket_install
                    $tag = [Modules]::scoop_bucket_install
                    if ([string]::IsNullOrWhiteSpace($name)) {
                        $name = $tag.ToString()
                    }
                    $header = "TASK [$role : $name]"
                    $marker = "*" * (CalulateSeparator -Message "$header ")
                    PrintInfo -Message "$header $marker"
                    ScoopBucketStateHandler -Module $module -Tag $tag -Mode $Mode
                }
                else {
                    $header = "skipped: TASK [$role : $name]"
                    $marker = "*" * (CalulateSeparator -Message "$header ")
                    PrintInfo -Message "$header $marker"
                    if ($module.Keys.Count -eq 0) {
                        PrintSkip -Message "skipping, no module specified"
                        continue
                    }
                    else {
                        throw "error: Invalid key spacified in module `"$($module.Keys -join ',')`""
                    }
                }
                NewLine
            }
        }
    }
    return
}

function ScoopBucketStateHandler {
    [CmdletBinding()]
    [OutputType([void])]
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

function ScoopAppStateHandler {
    [CmdletBinding()]
    [OutputType([void])]
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
        throw "erro: [${Tag}: $($moduleDetail.bucket)] => no matching bucket found."
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
            ScoopAppInstall -Tools $tools -Tag $Tag -DryRun $dryRun
        }
        $([StateElement]::absent) {
            ScoopAppUninstall -Tools $tools -Tag $Tag -DryRun $dryRun
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
            PrintCheck -Message "  [!] chck: [${Tag}: $Bucket] => $Source (installed: $false)"
        }
        else {
            PrintChanged -Message "  [!] chng: [${Tag}: $Bucket] => $Source (installed: $false)"
            PrintSpace
            scoop bucket add $Bucket $Source
        }
    }
    else {
        PrintSkip -Message "  [o] skip: [${Tag}: $Bucket]"
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
            PrintCheck -Message "  [!] chck: [${Tag}: $Bucket] (installed: $false)"
        }
        else {
            PrintChanged -Message "  [!] chng: [${Tag}: $Bucket] (installed: $false)"
            PrintSpace
            scoop bucket rm $Bucket
        }
    }
    else {
        PrintSkip -Message "  [o] skip: [${Tag}: $Bucket]"
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

    $prefix = "chng"
    if ($DryRun) {
        $prefix = "chck"
    }
    foreach ($tool in $Tools) {
        $output = scoop info $tool *>&1
        # may be typo manifest should throw fast
        if ($output -match "Could not find manifest for") {
            PrintFail -Message "  [x] fail: [${Tag}: $tool] => $($output)"
            throw "ACTION: please make sure your desired manifest '$tool' is available."
        }
        # successfully found manifest
        $installed = $output | Select-String -Pattern "Installed:"
        if ($installed.Line -match "no") {
            PrintChanged -Message "  [!] ${prefix}: [${Tag}: $tool] => $($installed.Line)"
            if ($DryRun) { continue }
            PrintSpace
            scoop install $tool
        }
        else {
            $outputStrict = scoop list $tool *>&1
            $installedStrictCheck = $outputStrict | Select-String -Pattern "failed"
            if ($null -ne $installedStrictCheck) {
                # previous installation was interupped
                PrintChanged -Message "  [!] ${prefix}: [${Tag}: $tool] => $($outputStrict | Select-Object -Skip 1 -First 2) (installed: $false, Failed previous installation, begin reinstall.)"
                if ($DryRun) { continue }
                PrintSpace
                scoop uninstall $tool
                PrintSpace
                scoop install $tool
            }
            else {
                $updatablePackages | ForEach-Object { Write-Verbose "$_" }
                $isUpdatable = $updatablePackages -contains $tool
                if (!$isUpdatable) {
                    PrintSkip -Message "  [o] skip: [${Tag}: $tool] => $($outputStrict | Select-Object -Skip 1 -First 2)"
                }
                else {
                    PrintChanged -Message "  [!] ${prefix}: [${Tag}: $tool] => $($outputStrict | Select-Object -Skip 1 -First 2) (updatable: $isUpdatable)"
                    if ($DryRun) { continue }
                    PrintSpace
                    scoop update $tool *>&1 | ForEach-Object { PrintInfo -Message $_ }
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
        if ($DryRun) {
            $output = scoop info $tool
            $installed = $output | Select-String -Pattern "Installed:"
            if ($installed.Line -match "no") {
                PrintSkip -Message "  [o] skip: [${Tag}: $tool] => Already uninstalled"
                Write-Verbose $installed.Line
            }
            else {
                PrintCheck -Message "  [!] chck: [${Tag}: $tool] => Require uninstall"
                PrintCheck -Message "$($installed.Line)$($output[++$installed.LineNumber])"
            }
        }
        else {
            $output = scoop info $tool
            $installed = $output | Select-String -Pattern "Installed:"
            if ($installed.Line -match "no") {
                PrintSkip -Message "  [o] skip: [${Tag}: $tool] => Already uninstalled"
            }
            else {
                PrintChanged -Message "  [!] chng: [${Tag}: $tool] => Require uninstall"
                scoop uninstall $tool
            }
        }
    }
}

function Invoke-ScoopPlaybook {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $false)]
        [Alias("FullName", "Path", "PSPath")]
        [string]$LiteralPath = "./site.yml",
        [RunMode]$Mode = [RunMode]::run
    )

    $before = $pwd
    try {
        NewLine

        # setup
        $header = "PRE [scoop : status]"
        $marker = "*" * (CalulateSeparator -Message "$header ")
        PrintInfo -Message "$header $marker"
        PrintInfo -Message "  [o] info: [run with '$Mode' mode]"

        # prerequisites
        PrintInfo -Message "  [o] info: [prerequisiting availability]"
        Prerequisites

        # update
        PrintCheck -Message "  [!] chck: [updating buckets]"
        UpdateScoop -UpdateScoop $true

        # status check
        PrintCheck -Message "  [!] chck: [checking scoop status]"
        RuntimeCheck

        NewLine
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
        VerifyYaml -BaseYaml $LiteralPath
        RunMain -BaseYaml $LiteralPath -Mode $Mode
    }
    catch [Exception] {
        PrintCheck -Message "ScriptStackTrace Detail: $($_.GetType()) $($_.ScriptStackTrace)"
        throw
    }
}

Set-Alias -Name Scoop-Playbook -Value Invoke-ScoopPlaybook
Export-ModuleMember -Function * -Alias Scoop-Playbook
