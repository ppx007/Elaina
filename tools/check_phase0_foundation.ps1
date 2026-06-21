& (Join-Path (Split-Path -Parent $PSScriptRoot) 'Invoke-ModuleCheck.ps1') -Module 'phase0_foundation' -CheckScriptPath 'tools/module-checks/legacy/check_phase0_foundation.ps1' -ScriptArguments $args
