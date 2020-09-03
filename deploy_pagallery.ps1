#!/usr/bin/env pwsh
[OutputType([void])]
param (
    [string]$Key,
)

$ModuleName = "ScoopPlaybook"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulePath = "$here/publish/$ModuleName"
$manifestPath = "$here/publish/$ModuleName/$ModuleName.psd1"

Import-Module $manifestPath -PassThru -Verbose
Publish-Module -Path $modulePath -NuGetApiKey $Key
