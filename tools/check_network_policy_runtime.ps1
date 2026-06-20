$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

$requiredFiles = @(
    'lib/src/network/network_policy.dart',
    'lib/src/network/network_policy_runtime.dart',
    'lib/src/foundation/storage/network_policy_storage_contracts.dart',
    'lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart',
    'test/network/network_policy_contract_test.dart',
    'test/network/network_policy_runtime_test.dart',
    'tools/network_policy_runtime_check.dart'
)

foreach ($file in $requiredFiles) {
    $path = Join-Path $root $file
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required network policy runtime file: $file"
    }
}

$runtimePath = Join-Path $root 'lib/src/network/network_policy_runtime.dart'
$runtime = Get-Content -LiteralPath $runtimePath -Raw

$requiredRuntimeTerms = @(
    'NetworkPolicyRuntimeBootstrap',
    'NetworkPolicyRuntime',
    'NetworkPolicyRuntimeFailureKind',
    'NetworkPolicyRuntimeFailure',
    'NetworkPolicyRuntimeActionResultKind',
    'NetworkPolicyRuntimeActionResult',
    'NetworkPolicyRuntimeRestartProjection',
    'NetworkPolicyRuntimeProjection',
    'capabilityUnsupported',
    'unavailable',
    'disposed',
    'policyNotFound',
    'policyDisabled',
    'evaluationFailed',
    'invalidAssignment',
    'snapshot(',
    'evaluate(',
    'assignProvider(',
    'disable(',
    'reenable(',
    'recordCapability(',
    'dispose(',
    'unavailable('
)

foreach ($term in $requiredRuntimeTerms) {
    if ($runtime -notmatch [regex]::Escape($term)) {
        throw "Network policy runtime missing required term: $term"
    }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/elaina.dart') -Raw
if ($barrel -notmatch [regex]::Escape("export 'src/network/network_policy_runtime.dart';")) {
    throw 'Public Dart contract barrel missing network policy runtime export.'
}

$checkerPath = Join-Path $root 'tools/network_policy_runtime_check.dart'
$checker = Get-Content -LiteralPath $checkerPath -Raw
$requiredCheckerTerms = @(
    "import '../lib/elaina.dart';",
    'DeterministicNetworkPolicyStore',
    'StreamCacheInvalidationBus',
    'NetworkPolicyRuntimeBootstrap',
    'NetworkPolicyRuntimeFailureKind.policyDisabled',
    'NetworkPolicyRuntimeFailureKind.capabilityUnsupported',
    '.unavailable(',
    'dispose()',
    '_expect'
)

foreach ($term in $requiredCheckerTerms) {
    if ($checker -notmatch [regex]::Escape($term)) {
        throw "Network policy runtime checker missing required term: $term"
    }
}

& dart run $checkerPath
if ($LASTEXITCODE -ne 0) {
    throw "Network policy runtime Dart checker failed with exit code $LASTEXITCODE"
}

$filesToScan = @(
    'lib/src/network/network_policy_runtime.dart',
    'test/network/network_policy_runtime_test.dart',
    'tools/network_policy_runtime_check.dart'
)

$blockedTerms = @(
    ('D' + 'nsClient'),
    ('Do' + 'HClient'),
    ('Do' + 'TClient'),
    ('Pr' + 'oxyClient'),
    ('Pr' + 'oxyServer'),
    ('Pa' + 'cParser'),
    ('Vp' + 'nService'),
    ('Tu' + 'nInterface'),
    ('Kernel' + 'Filter'),
    ('D' + 'PI'),
    ('Packet' + 'Capture'),
    ('So' + 'cket'),
    ('Platform' + 'Network'),
    ('Flutter' + 'UI'),
    ('Native' + 'Binding'),
    ('dart' + ':ffi'),
    ('Dynamic' + 'Library'),
    ('Method' + 'Channel'),
    ('Event' + 'Channel'),
    ('Diagnostics' + 'Center'),
    ('Diagnostics' + 'Action'),
    ('Provider' + 'Dispatch'),
    ('R' + 'SS'),
    ('B' + 'T'),
    ('Online' + 'Rule'),
    ('Web' + 'View'),
    ('cap' + 'tcha'),
    ('lib' + 'torrent'),
    ('m' + 'pv'),
    ('v' + 'lc'),
    ('media' + '-kit'),
    ('yuc' + '.wiki'),
    ('automatic' + 'CaptchaSolving'),
    ('credential' + 'Guessing')
)

foreach ($file in $filesToScan) {
    $path = Join-Path $root $file
    $content = Get-Content -LiteralPath $path -Raw
    foreach ($term in $blockedTerms) {
        if ($content -match [regex]::Escape($term)) {
            throw "Forbidden Step 29 boundary term '$term' found in $file"
        }
    }
}

$runtimeImports = Get-Content -LiteralPath $runtimePath | Where-Object { $_ -match '^import ' }
$blockedImports = @(
    ('dart' + ':io'),
    ('dart' + ':ffi'),
    ('package' + ':flutter'),
    ('player' + '_adapter'),
    ('playback' + '_controller'),
    ('m' + 'pv'),
    ('v' + 'lc'),
    ('media' + '_kit'),
    ('shader'),
    ('native' + '_renderer'),
    ('diagnostics' + '_center'),
    ('online' + '_rule'),
    ('rss' + '_'),
    ('fallback' + '_adapter'),
    ('bt' + '_task'),
    ('Method' + 'Channel'),
    ('Event' + 'Channel')
)

foreach ($importLine in $runtimeImports) {
    foreach ($term in $blockedImports) {
        if ($importLine -match [regex]::Escape($term)) {
            throw "Forbidden import '$term' in runtime: $importLine"
        }
    }
}

Write-Output 'Network policy runtime checks passed.'
