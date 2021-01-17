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

Install required modules.

```ps1
Install-Module PowerShell-Yaml -Scope CurrentUser
Install-Module ScoopPlaybook -Scope CurrentUser
```

create ansible like folder structures, and place main.yml

```ps1
mkdir roles/main/tasks
New-Item roles/main/tasks/main.yml
code roles/main/tasks/main.yml
```

define your scoop bucket and package installation in in main.yml.

```yaml
- name: "Install linux tools"
  scoop_install:
    state: present
    bucket: main
    name:
      - busybox

- name: "Install windows tools"
  scoop_install:
    state: present
    bucket: main
    name:
      - 7zip

- name: "Install extras bucket"
  scoop_bucket_install:
    state: present
    bucket: extras

- name: "Install extras tools"
  scoop_install:
    state: present
    bucket: extras
    name:
      - gitkraken
```

Run ScoopPlaybook to execure installation.

```shell
Import-Module ScoopPlaybook.
Scoop-Playbook
```

you can uninstall scoop package via state `absent`.

```yaml
- name: "UnInstall windows tools"
  scoop_install:
    state: absent
    bucket: main
    name:
      - 7zip
```

more samples? see https://github.com/guitarrapc/local-provisioner/tree/master/envs/windows

## Test 

```ps1
Install-Module Pester -Force -Scope CurrentUser -SkipPublisherCheck
Invoke-Pester
```
