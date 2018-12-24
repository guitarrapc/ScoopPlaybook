#!/usr/bin/env pwsh
[OutputType([void])]
param (
    [string]$Version,
    [string]$TagVersion
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$path = "$here/src/ScoopPlaybook.psd1"
$guid = "38ac9351-b293-4166-9ae5-13dd349d6ad6"
$publish = "./publish/ScoopPlaybook"
$targets = "ScoopPlaybook.ps*1"

# validation
if ([string]::IsNullOrWhiteSpace($Version)) {
    Write-Host -ForeGroundColor Yellow "Version not specified, please specify semantic version."
    return;
}
if (![string]::IsNullOrWhiteSpace($TagVersion)) {
    Write-Host -ForeGroundColor Yellow "APPVEYOR_REPO_TAG_NAME detected. override Version via $TagVersion."
    $Version = $TagVersion
}
if (Test-Path $path) {
    $manifest = Invoke-Expression (Get-Content $path -Raw)
    if ($manifest.ModuleVersion -eq $Version) {
        Write-Host -ForeGroundColor Yellow "Same version specified, just copy existsis."
        Prepare -Path ./publish/ScoopPlaybook
        Copy-Item -Path src/*, *.md -Destination "$publish/"
        return
    }
}

# setup
function Update([string]$Path, [string]$Version, [string]$Guid) {
    New-ModuleManifest -Path $Path -Guid $Guid -PowerShellVersion 5.1 -Author guitarrapc -ModuleVersion $Version -RootModule ScoopPlaybook.psm1 -Description "PowerShell Module to run scoop like ansible playbook" -CompatiblePSEditions Core, Desktop -Tags UTF8BOM -ProjectUri https://github.com/guitarrapc/ScoopPlaybook -LicenseUri https://github.com/guitarrapc/ScoopPlaybook/blob/master/LICENSE.md -ReleaseNotes https://github.com/guitarrapc/ScoopPlaybook/releases/tag/$Version
}

function Prepare([string]$Path) {
    if (Test-Path $Path) {
        Remove-Item $Path -Force -Recurse
    }
    New-Item -Path $Path -ItemType Directory -Force    
}

# run
Update -Path $path -Version $Version -Guid $Guid
Prepare -Path ./publish/ScoopPlaybook
Copy-Item -Path src/*, *.md -Destination "$publish/"