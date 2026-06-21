& (Join-Path (Split-Path -Parent $PSScriptRoot) 'Invoke-ModuleCheck.ps1') -Module 'bangumi_runtime' -CheckScriptPath 'tools/module-checks/legacy/check_bangumi_runtime.ps1' -ScriptArguments $args
