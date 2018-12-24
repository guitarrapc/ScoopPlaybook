#!/usr/bin/env pwsh
[OutputType([void])]
param (
    [string]$ModuleName,
    [string]$NuGetApiKey,
    [string]$BuildBranch
)

# validation
if ($env:APPVEYOR_REPO_BRANCH -notmatch $BuildBranch) {
    Write-Host -ForeGroundColor Yellow "`"Appveyor`" deployment has been skipped as environment variable has not matched (`"APPVEYOR_REPO_BRANCH`" is `"$env:APPVEYOR_REPO_BRANCH`", should be `"$branch`""
    return
}
if ([string]::IsNullOrWhiteSpace($env:APPVEYOR_REPO_TAG_NAME)) {
    Write-Host -ForeGroundColor Yellow "`"Appveyor`" deployment has been skipped as `"APPVEYOR_REPO_TAG_NAME`" environment variable is blank"
    return
}
if ([string]::IsNullOrWhiteSpace($NuGetApiKey)) {
    Write-Host -ForeGroundColor Yellow "`"Appveyor`" deployment has been skipped as `"NuGetApiKey`" is not specified."
    return
}

# Run
Write-Host -ForegroundColor Green 'Running AppVeyor deploy script'

# environment variables
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = "$here/publish/$moduleName"
$manifestPath = "$here/publish/$moduleName/$moduleName.psd1"
$version = $env:APPVEYOR_REPO_TAG_NAME

# Test Version is correct
$manifest = Invoke-Expression (Get-Content $manifestPath -Raw)
if ($manifest.ModuleVersion -ne $version) {
    throw "`"Appveyor`" deployment has been canceled. Version update failed (`Manifest Version is `"${$manifest.ModuleVersion}`", should be `"$version`")"
}

# Publish to PS Gallery
Write-Host -ForeGroundColor Green 'Publishing module to Powershell Gallery'
Import-Module $manifestPath -PassThru -Verbose
Publish-Module -Path $modulePath -NuGetApiKey $NuGetApiKey
