#!/usr/bin/env pwsh
[OutputType([void])]
param (
    [string]$Version,
    [string]$TagVersion
)
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$path = "$here/src/ScoopPlaybook.psd1"
$publish = "./publish/ScoopPlaybook"

# setup
function Update([string]$Path, [string]$Version) {
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

function Prepare([string]$Path) {
    if (Test-Path $Path) {
        Remove-Item $Path -Force -Recurse
    }
    New-Item -Path $Path -ItemType Directory -Force    
}

# validation
if ([string]::IsNullOrWhiteSpace($Version)) {
    Write-Host -ForeGroundColor Yellow "Version not specified, please specify semantic version."
    return;
}
else {
    $Version = [Version]"0.0.$Version"
}
if (![string]::IsNullOrWhiteSpace($TagVersion)) {
    $tv = [Version]"1.0.0"
    if ([Version]::TryParse($TagVersion, [ref]$tv)) {
        Write-Host -ForeGroundColor Yellow "TagVersion detected. override Version via $TagVersion."
        $Version = $TagVersion
    }
    else {
        Write-Host -ForeGroundColor Yellow "TagVersion detected but was not an Version type."
    }
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

# run
Update -Path $path -Version $Version
Prepare -Path ./publish/ScoopPlaybook
Copy-Item -Path src/*, *.md -Destination "$publish/"