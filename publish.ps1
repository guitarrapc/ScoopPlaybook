#!/usr/bin/env pwsh
param (
    [Parameter(Mandatory = $true)]
    [string]$Version
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$path = "$here/src/ScoopPlaybook.psd1"
$publish = "./publish/ScoopPlaybook"
$output = "./publish/ScoopPlaybook"

# setup
function UpdateManifest([string]$Path, [string]$Version) {
    $params = @{
        Path              = $Path
        ModuleVersion     = $Version
        FunctionsToExport = ("Invoke-ScoopPlaybook")
        AliasesToExport   = ("Scoop-Playbook")
        ReleaseNotes      = "https://github.com/guitarrapc/ScoopPlaybook/releases/tag/$Version"
    }
    Update-ModuleManifest @params
}

function GenManifest([string]$Path, [string]$Guid, [string]$Version) {
    $params = @{
        Path                 = $Path
        Guid                 = $Guid
        PowerShellVersion    = "5.1"
        Author               = "guitarrapc"
        ModuleVersion        = $Version
        RootModule           = "ScoopPlaybook.psm1"
        Description          = "PowerShell Module to run scoop like ansible playbook"
        CompatiblePSEditions = ("Core", "Desktop")
        FunctionsToExport    = ("Invoke-ScoopPlaybook")
        AliasesToExport      = ("Scoop-Playbook")
        Tags                 = "Scoop"
        ProjectUri           = "https://github.com/guitarrapc/ScoopPlaybook"
        LicenseUri           = "https://github.com/guitarrapc/ScoopPlaybook/blob/master/LICENSE.md"
        ReleaseNotes         = "https://github.com/guitarrapc/ScoopPlaybook/releases/tag/$Version"
    }
    New-ModuleManifest @params
}

function PrepareOutput([string]$Path) {
    if (Test-Path $Path) {
        Remove-Item $Path -Force -Recurse > $null
    }
    New-Item -Path $Path -ItemType Directory -Force > $null
}

# validation
if (!(Test-Path -Path $path)) {
    throw "$path not found exception."
}
if ([string]::IsNullOrWhiteSpace($Version)) {
    throw "Version parameter is empty. please specify Version"
}
$v = [Version]"1.0.0"
if (![Version]::TryParse($Version, [ref]$v)) {
    throw "Version was not an Version type, please specify like x.x.x"
}

# main
PrepareOutput -Path $output
UpdateManifest -Path $path -Version $v
Copy-Item -Path src/*, *.md -Destination "$publish/" -PassThru