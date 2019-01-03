$here = Split-Path -Parent $MyInvocation.MyCommand.Path
Import-Module $here/../src/ScoopPlaybook.psm1 -Force