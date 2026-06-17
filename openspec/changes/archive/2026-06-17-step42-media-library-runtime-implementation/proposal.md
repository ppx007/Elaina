# Step 42 Media Library Runtime Implementation

## Summary

Implement the first concrete media-library runtime slice after the SQLite
storage foundation. This change keeps UI ownership external while making the
core media-library runtime usable for local file scan, import, persisted
catalog/history/binding state, and playback handoff.

## Key Changes

- Add a concrete local-file media scanner backed by `dart:io` directory
  traversal.
- Add storage-backed media-library adapters that map `StorageFoundation`
  catalog/history/binding records into the existing Domain media runtime
  contracts.
- Add a storage-backed media-library bootstrap/factory for app composition
  roots to inject storage, scanner, handoff, invalidation, and clock inputs.
- Add SQLite restart tests and a non-UI smoke checker covering scan -> import
  -> refresh -> history -> binding -> playback handoff.
- Extend media-library runtime boundary checks to require the concrete scanner
  and storage-backed composition while keeping SQLite/SQL details inside
  Foundation/Storage.
- Document Step 42 usage and non-goals.

## Non-Goals

- Do not modify `lib/src/ui/**`, `lib/main.dart`, or `windows/**`.
- Do not implement media-library pages, routes, file picker UX, thumbnails,
  metadata enrichment UI, or user-visible navigation.
- Do not add Provider metadata matching, RSS automation, BT streaming, network
  clients, or platform plugins.
- Do not make Domain runtime code import SQLite packages or issue SQL.

## Validation

- `flutter test test\domain\media\media_library_runtime_test.dart`
- New focused concrete media-library tests.
- `powershell -ExecutionPolicy Bypass -File "tools\check_media_library_runtime.ps1"`
- `openspec.cmd validate "step42-media-library-runtime-implementation" --strict`
- `openspec.cmd validate --all`
- `dart analyze`
- `flutter analyze`
- `flutter test`
- `powershell -ExecutionPolicy Bypass -File "tools\check_automation_extension_core.ps1"`

