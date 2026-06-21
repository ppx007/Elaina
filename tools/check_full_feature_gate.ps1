& (Join-Path (Split-Path -Parent $PSScriptRoot) 'Invoke-ModuleCheck.ps1') -Module 'full_feature_gate' -CheckScriptPath 'tools/module-checks/legacy/check_full_feature_gate.ps1' -ScriptArguments $args
