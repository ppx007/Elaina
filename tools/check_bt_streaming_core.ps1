& (Join-Path (Split-Path -Parent $PSScriptRoot) 'Invoke-ModuleCheck.ps1') -Module 'bt_streaming_core' -CheckScriptPath 'tools/module-checks/legacy/check_bt_streaming_core.ps1' -ScriptArguments $args
