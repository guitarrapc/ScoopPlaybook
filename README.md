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

## Quick Start

[Install scoop beforehand](https://scoop.sh/), then clone repo and run module.

```ps1
Install-Module PowerShell-Yaml -Scope CurrentUser
Install-Module ScoopPlaybook -Scope CurrentUser

git clone https://github.com/guitarrapc/ScoopPlaybook.git
cd ScoopPlaybook/samples
Scoop-Playbook
```

This sample will install busybox, 7zip and gitkraken for you.

## Step by step Start

create ansible like folder structures, and place main.yml

```ps1
mkdir roles/main/tasks
```

define your scoop bucket and package installation in in main.yml.

```shell
New-Item roles/main/tasks/main.yml
code roles/main/tasks/main.yml
```

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

define your site.yaml to select which role to call.

```shell
New-Item site.yml
code site.yml
```

```yaml
name: main
roles:
  - main
```

Run ScoopPlaybook to execure installation.

```shell
Install-Module PowerShell-Yaml -Scope CurrentUser
Install-Module ScoopPlaybook -Scope CurrentUser
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

## SCHEME

**site.yaml scheme**

Select which role to install/uninstall.
This file location is where your must run `Scoop-Playbook` Cmdlet.

```yaml
name: "<string>" # REQUIRED: NAME OF YOUR DEFINITION
roles:
  - "<string>" # REQUIRED: ROLE NAME TO CALL
```

**Role - scoop_install**

Install/Uninstall scoop package from selected bucket.

```yaml
- name: "<string>" # REQUIRED: name of role
  scoop_install:
    state: "present|absent" # OPTIONAL (default "present"): enums of present or absent. present to install, absent to uninstall.
    bucket: "<string>" # REQUIRED: bucket name to install package.
    name:
      - "<string>" # REQUIRED: list of strings to identify package names
```

**Role - scoop_bucket_install**

Install/Uninstall scoop bucket.

```yaml
- name: "<string>" # REQUIRED: name of role
  scoop_bucket_install:
    state: "present|absent" # OPTIONAL: present to install, absent to uninstall. default "present".
    bucket: "<string>" # REQUIRED: bucket name to install package.
```

## Test 

```ps1
Install-Module Pester -Force -Scope CurrentUser -SkipPublisherCheck
Invoke-Pester
```
