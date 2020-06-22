![build](https://github.com/guitarrapc/ScoopPlaybook/workflows/build/badge.svg) ![release](https://github.com/guitarrapc/ScoopPlaybook/workflows/release/badge.svg)

## ScoopPlaybook

PowerShell Module to Play Scoop like Ansible

* :white_check_mark: Desktop
* :white_check_mark: NetCore

## Installation

```ps1
Install-Module ScoopPlaybook -Scope CurrentUser
```

## Functions

Function | Description
---- | ----
Scoop-Playbook | Run scoop as with ansible structured YAML definitions

## Usage

see https://github.com/guitarrapc/local-provisioner/tree/master/envs/windows


## Test 

Pester 4.x

```
Install-Module Pester -Force -Scope CurrentUser -SkipPublisherCheck
```