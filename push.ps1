#!/usr/bin/env pwsh
param (
    [Parameter(Mandatory = $true)]
    [string]$Key,
    [bool]$DryRun = $true
)

$ModuleName = "ScoopPlaybook"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = "$here/publish/$ModuleName"
$manifestPath = "$here/publish/$ModuleName/$ModuleName.psd1"

Import-Module $manifestPath -PassThru -Verbose -Force
Get-Module -Name $ModuleName
if ($DryRun) {
    Write-Host -Message "Dryrun detected, finish without push."
    return
}
Publish-Module -Path $modulePath -NuGetApiKey $Key
