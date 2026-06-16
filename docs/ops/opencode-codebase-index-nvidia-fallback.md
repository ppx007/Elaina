# OpenCode Codebase Index NVIDIA Fallback Patch

## Purpose

This archive preserves the local compatibility patch for `opencode-codebase-index` when using the current custom NVIDIA embedding model:

* Provider: `custom`
* Model: `nvidia/nv-embedcode-7b-v1`
* Dimensions: `4096`

The upstream plugin cache may be overwritten by `opencode-codebase-index@latest` updates. Reapply this archive when codebase indexing starts failing again with deterministic embedding `500` responses, or when the plugin bundle loses the fallback helpers.

## Runtime Files Patched

Default plugin bundle:

```text
C:\Users\q1354\.cache\opencode\packages\opencode-codebase-index@latest\node_modules\opencode-codebase-index\dist\index.js
```

Default codebase config:

```text
C:\Users\q1354\.config\opencode\codebase-index.json
```

Known backups created during the original repair:

```text
C:\Users\q1354\.cache\opencode\packages\opencode-codebase-index@latest\node_modules\opencode-codebase-index\dist\index.js.bak-codex-fallback
C:\Users\q1354\.config\opencode\codebase-index.json.bak-codex-batch
```

The reapply script creates its own one-time backups with suffix `.bak-codex-nvidia-fallback`.

## What The Patch Does

`CustomEmbeddingProvider.embedRequest()` keeps the NVIDIA `input_type` compatibility:

* Query embeddings use `input_type: "query"`.
* Document and batch embeddings use `input_type: "passage"`.

On retryable `5xx` responses from NVIDIA custom embeddings:

1. Multi-text batch failures split back to single-text requests.
2. Single-text failures retry normalized text variants:
   * remove generated codebase preamble (`bodyOnly`)
   * strip Markdown punctuation (`stripMarkdown`)
   * reduce to words/numbers (`wordOnly`)

The fallback does not suppress:

* 4xx non-retryable provider errors
* dimension mismatches
* unexpected embedding response shapes

## Config Archived

The intended config shape is:

```json
{
  "customProvider": {
    "model": "nvidia/nv-embedcode-7b-v1",
    "dimensions": 4096,
    "concurrency": 2,
    "requestIntervalMs": 1000,
    "maxBatchSize": 4
  }
}
```

This preserves the current request rate of at most two requests per second while increasing successful batch throughput to up to eight text parts per second.

## Reapply

From the project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\.opencode\patches\reapply-codebase-index-nvidia-fallback.ps1
```

If OpenCode changes the package cache path, pass the new bundle path explicitly:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\.opencode\patches\reapply-codebase-index-nvidia-fallback.ps1 `
  -PluginPath "C:\path\to\opencode-codebase-index\dist\index.js"
```

The script does not print API keys. It updates only the plugin bundle and non-secret config fields.

## Verify

Check plugin syntax:

```powershell
node --check "$env:USERPROFILE\.cache\opencode\packages\opencode-codebase-index@latest\node_modules\opencode-codebase-index\dist\index.js"
```

Check non-secret config fields:

```powershell
$cfg = Get-Content -Encoding UTF8 -Raw -LiteralPath "$env:USERPROFILE\.config\opencode\codebase-index.json" | ConvertFrom-Json
[PSCustomObject]@{
  MaxBatchSize      = $cfg.customProvider.maxBatchSize
  Concurrency       = $cfg.customProvider.concurrency
  RequestIntervalMs = $cfg.customProvider.requestIntervalMs
  Model             = $cfg.customProvider.model
  Dimensions        = $cfg.customProvider.dimensions
} | Format-List
```

Expected:

```text
MaxBatchSize      : 4
Concurrency       : 2
RequestIntervalMs : 1000
Model             : nvidia/nv-embedcode-7b-v1
Dimensions        : 4096
```

Then trigger the OpenCode `codebase` plugin's failed-batch retry tool, usually `retry_failed_batches`, so existing entries in `.opencode/index/failed-batches.json` can be embedded and written back through plugin-owned storage.

## Notes

Do not hand-edit `codebase.db`, `vectors`, or `vectors.meta.json` unless the plugin itself is unusable. The vector store and SQLite metadata must stay consistent, so retry through the plugin path is safer than manually inserting missing embeddings.
