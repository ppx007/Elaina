& (Join-Path (Split-Path -Parent $PSScriptRoot) 'Invoke-ModuleCheck.ps1') -Module 'danmaku_runtime' -CheckScriptPath 'tools/module-checks/legacy/check_danmaku_runtime.ps1' -ScriptArguments $args
