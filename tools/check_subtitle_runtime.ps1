& (Join-Path (Split-Path -Parent $PSScriptRoot) 'Invoke-ModuleCheck.ps1') -Module 'subtitle_runtime' -CheckScriptPath 'tools/module-checks/legacy/check_subtitle_runtime.ps1' -ScriptArguments $args
