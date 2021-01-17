#!/usr/bin/env pwsh
param (
    [Parameter(Mandatory = $true)]
    [string]$Version
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$path = "$here/src/ScoopPlaybook.psd1"
$publish = "$here/publish/ScoopPlaybook"
$rootModule = "ScoopPlaybook.psm1"
$functionToExport = @("Invoke-ScoopPlaybook")
$aliasToExport = @("Scoop-Playbook")

# validation
if ([string]::IsNullOrWhiteSpace($Version)) {
    throw "Version parameter is empty. please specify Version"
}
$v = [Version]"1.0.0"
if (![Version]::TryParse($Version, [ref]$v)) {
    throw "Version was not an Version type, please specify like x.x.x"
}

# main
New-Item -Path $Publish -ItemType Directory -Force > $null
if (!(Test-Path -Path $path)) {
    Write-Host "Generating manifest."
    $genParams = @{
        Path                 = $path
        Guid                 = [Guid]::NewGuid().ToString()
        PowerShellVersion    = "5.1"
        Author               = "guitarrapc"
        ModuleVersion        = $v
        RootModule           = $rootModule
        Description          = "PowerShell Module to run scoop like ansible playbook"
        CompatiblePSEditions = ("Core", "Desktop")
        FunctionsToExport    = $functionToExport
        AliasesToExport      = $aliasToExport
        CmdletsToExport      = @()
        VariablesToExport    = @()
        Tags                 = "scoop"
        ProjectUri           = "https://github.com/guitarrapc/ScoopPlaybook"
        LicenseUri           = "https://github.com/guitarrapc/ScoopPlaybook/blob/master/LICENSE.md"
        ReleaseNotes         = "https://github.com/guitarrapc/ScoopPlaybook/releases/tag/$Version"
    }
    New-ModuleManifest @genParams
}
else {
    Write-Host "Updading existing manifest."
    $updateParams = @{
        Path              = $path
        ModuleVersion     = $v
        FunctionsToExport = $functionToExport
        AliasesToExport   = $aliasToExport
        ReleaseNotes      = "https://github.com/guitarrapc/ScoopPlaybook/releases/tag/$Version"
    }
    Update-ModuleManifest @updateParams
}
Copy-Item -Path "$here/src/*", *.md -Destination "$publish/" -PassThru