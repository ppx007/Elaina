& (Join-Path (Split-Path -Parent $PSScriptRoot) 'Invoke-ModuleCheck.ps1') -Module 'player_core' -CheckScriptPath 'tools/module-checks/legacy/check_player_core.ps1' -ScriptArguments $args
