$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot

$requiredFiles = @(
    'lib/src/foundation/diagnostics/diagnostics_center.dart',
    'lib/src/foundation/diagnostics/diagnostics_center_runtime.dart',
    'lib/src/foundation/storage/diagnostics_storage_contracts.dart',
    'lib/src/foundation/cache_invalidation/cache_invalidation_bus.dart',
    'test/foundation/diagnostics_center_contract_test.dart',
    'test/foundation/diagnostics_center_runtime_test.dart',
    'tools/diagnostics_center_runtime_check.dart'
)

foreach ($file in $requiredFiles) {
    $path = Join-Path $root $file
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing required diagnostics runtime file: $file"
    }
}

$runtimePath = Join-Path $root 'lib/src/foundation/diagnostics/diagnostics_center_runtime.dart'
$runtime = Get-Content -LiteralPath $runtimePath -Raw

$requiredRuntimeTerms = @(
    'DiagnosticsCenterRuntimeBootstrap',
    'DiagnosticsCenterRuntime',
    'DiagnosticsCenterRuntimeFailureKind',
    'DiagnosticsCenterRuntimeFailure',
    'DiagnosticsCenterRuntimeActionResultKind',
    'DiagnosticsCenterRuntimeActionResult',
    'DiagnosticsCenterRuntimeProjection',
    'DiagnosticsCenterRuntimeRestartProjection',
    'capabilityUnsupported',
    'unavailable',
    'disposed',
    'missingSchema',
    'recordFailure',
    'snapshotFailure',
    'retentionFailure',
    'exportFailure',
    'recordSchema(',
    'recordEvent(',
    'querySnapshot(',
    'enforceRetention(',
    'describeLocalExport(',
    'recordCapability(',
    'snapshot(',
    'dispose(',
    'unavailable('
)

foreach ($term in $requiredRuntimeTerms) {
    if ($runtime -notmatch [regex]::Escape($term)) {
        throw "Diagnostics runtime missing required term: $term"
    }
}

$barrel = Get-Content -LiteralPath (Join-Path $root 'lib/celesteria.dart') -Raw
if ($barrel -notmatch [regex]::Escape("export 'src/foundation/diagnostics/diagnostics_center_runtime.dart';")) {
    throw 'Public Dart contract barrel missing diagnostics center runtime export.'
}

$checkerPath = Join-Path $root 'tools/diagnostics_center_runtime_check.dart'
$checker = Get-Content -LiteralPath $checkerPath -Raw
$requiredCheckerTerms = @(
    "import '../lib/celesteria.dart';",
    'DiagnosticsCenterRuntimeBootstrap',
    'DiagnosticsCenterRuntimeFailureKind.capabilityUnsupported',
    'DiagnosticsCenterRuntimeFailureKind.disposed',
    'DiagnosticsCenterRuntimeFailureKind.unavailable',
    'DiagnosticsCenterRuntimeFailureKind.missingSchema',
    'DiagnosticsCenterRuntimeFailureKind.snapshotFailure',
    'DiagnosticsCenterRuntimeFailureKind.retentionFailure',
    'DiagnosticsCenterRuntimeFailureKind.exportFailure',
    'DiagnosticsCenterRuntimeFailureKind.recordFailure',
    'DeterministicDiagnosticsStore',
    'DeterministicDiagnosticsEventRegistry',
    'StreamCacheInvalidationBus',
    'DiagnosticsSchemaRegistered',
    'DiagnosticsEventRecorded',
    'DiagnosticsSnapshotCreated',
    'DiagnosticsExportRequestRecorded',
    'DiagnosticsExportOutcomeRecorded',
    'DiagnosticsRetentionEnforced',
    'DiagnosticsCapabilityChanged',
    '_expect'
)

foreach ($term in $requiredCheckerTerms) {
    if ($checker -notmatch [regex]::Escape($term)) {
        throw "Diagnostics runtime checker missing required term: $term"
    }
}

& dart run $checkerPath
if ($LASTEXITCODE -ne 0) {
    throw "Diagnostics runtime Dart checker failed with exit code $LASTEXITCODE"
}

$filesToScan = @(
    'lib/src/foundation/diagnostics/diagnostics_center_runtime.dart',
    'test/foundation/diagnostics_center_runtime_test.dart',
    'tools/diagnostics_center_runtime_check.dart'
)

$blockedTerms = @(
    ('play' + 'back'),
    ('Pr' + 'ovider'),
    ('RSS'),
    ('On' + 'lineRule'),
    ('Web' + 'View'),
    ('B' + 'T'),
    ('net' + 'workpolicy'),
    ('Nat' + 'ive'),
    ('d' + 'art:ffi'),
    ('Method' + 'Channel'),
    ('Event' + 'Channel'),
    ('tele' + 'metry'),
    ('cl' + 'oud'),
    ('MPV'),
    ('VLC'),
    ('media' + '-kit'),
    ('cap' + 'tcha'),
    ('yuc' + '.wiki'),
    ('lib' + 'torrent'),
    ('Flutter' + 'UI')
)

foreach ($file in $filesToScan) {
    $path = Join-Path $root $file
    $content = Get-Content -LiteralPath $path -Raw
    foreach ($term in $blockedTerms) {
        if ($content -match [regex]::Escape($term)) {
            throw "Forbidden Step 30 boundary term '$term' found in $file"
        }
    }
}

$runtimeImports = Get-Content -LiteralPath $runtimePath | Where-Object { $_ -match '^import ' }
$blockedImports = @(
    ('dart' + ':io'),
    ('dart' + ':ffi'),
    ('package' + ':flutter'),
    ('mpv'),
    ('vlc'),
    ('media' + '_kit'),
    ('lib' + 'torrent'),
    ('play' + 'back'),
    ('prov' + 'ider'),
    ('on' + 'line_rule'),
    ('web' + 'view'),
    ('bt' + '_task'),
    ('method' + 'channel'),
    ('event' + 'channel'),
    ('native'),
    ('tele' + 'metry'),
    ('cl' + 'oud')
)

foreach ($importLine in $runtimeImports) {
    foreach ($term in $blockedImports) {
        if ($importLine -match [regex]::Escape($term)) {
            throw "Forbidden import '$term' in runtime: $importLine"
        }
    }
}

Write-Output 'Diagnostics center runtime checks passed.'
