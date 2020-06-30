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

define your scoop bucket, package installation.

```yaml
- name: "Install linux tools"
  scoop_install:
    state: present
    bucket: main
    name:
      - gow

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

Pester 4.x

scoop changed handling, test won't work currently. (do not run)
<s>Install-Module Pester -Force -Scope CurrentUser -SkipPublisherCheck</s>
