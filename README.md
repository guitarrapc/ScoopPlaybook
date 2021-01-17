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

Create ansible like folder structures, let make main role.

```ps1
mkdir roles/main/tasks
```

Define your scoop bucket and package installation definition in your main role's task/main.yml.

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

Define your site.yml to select which role to use.

```shell
New-Item site.yml
code site.yml
```

```yaml
name: main
roles:
  - main
```

You are ready, let's run ScoopPlaybook Cmdlet to install scoop packages and buckets you desired.

```shell
Install-Module PowerShell-Yaml -Scope CurrentUser
Install-Module ScoopPlaybook -Scope CurrentUser
Scoop-Playbook
```

You can uninstall scoop package via state `absent`.

```yaml
- name: "UnInstall windows tools"
  scoop_install:
    state: absent
    bucket: main
    name:
      - 7zip
```

more samples? see https://github.com/guitarrapc/local-provisioner/tree/master/envs/windows

## Definition

### Structures

Structure is follow to ansible, but there are only role function, no variables or any.

* site.yml: site.yml is entrypoint of scheme, and select which role to call.
* role: role must place under `roles/<roleName>` folder. Site.yml call role must match a role folder name.
* task: task must place under `roles/<roleName>/tasks/main.yml`. task contains multiple modules.
* module: module offer what you can do. there are 2 modules you can use.
    * scoop_install
    * scoop_bucket_install

`site.yml` file location is where your must run `Scoop-Playbook` Cmdlet.
Here's sample structures.

```
site.yml
└───roles
    ├───main
    │   └───tasks
    │       └───main.yml
    └───extras
        └───tasks
            └───main.yml
```


### SCHEME

**site.yml scheme**

Select which role to call.

```yaml
name: "<string>" # REQUIRED: name of you definition
roles:
  - "<string>" # REQUIRED: role name to call. this roll name must match rolle file name.
```

**Module - scoop_install module**

`scoop_install` Module offer Install/Uninstall scoop package from selected bucket.

```yaml
- name: "<string>" # REQUIRED: name of module
  scoop_install:
    state: "present|absent" # OPTIONAL (default "present"): enums of present or absent. present to install, absent to uninstall.
    bucket: "<string>" # REQUIRED: bucket name to install package.
    name:
      - "<string>" # REQUIRED: list of strings to identify package names
```

**Module - scoop_bucket_install module**

`scoop_bucket_install` module offers Install/Uninstall scoop bucket.

```yaml
- name: "<string>" # REQUIRED: name of module
  scoop_bucket_install:
    state: "present|absent" # OPTIONAL: present to install, absent to uninstall. default "present".
    bucket: "<string>" # REQUIRED: bucket name to install package.
```

## Test 

```ps1
Install-Module Pester -Force -Scope CurrentUser -SkipPublisherCheck
Install-Module PSScriptAnalyzer -Force -Scope CurrentUser
Install-Module PowerShell-Yaml -Force -Scope CurrentUser
Invoke-Pester
```
