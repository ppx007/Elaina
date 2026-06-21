& (Join-Path (Split-Path -Parent $PSScriptRoot) 'Invoke-ModuleCheck.ps1') -Module 'player_smoke_gate' -CheckScriptPath 'tools/module-checks/legacy/check_player_smoke_gate.ps1' -ScriptArguments $args
