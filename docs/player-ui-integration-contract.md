# Player UI Integration Contract

Step 34 defines how the external UI/app-shell model should connect to the
Codex-owned playback core. This is an integration contract only. UI pages,
routes, widgets, file picker UX, video surfaces, and Windows runner code remain
outside Codex ownership.

## Composition Root

The app composition root owns long-lived runtime objects. For local file
playback, create the concrete playback composition and inject it into the
player core:

```dart
final PlayerRuntimeCompositionContract composition =
    mediaKitLocalFilePlayerRuntimeComposition(libmpvPath: optionalLibMpvPath);

final PlayerCoreBootstrap playerCore = PlayerCoreBootstrap.withComposition(
  composition: composition,
  foundationDependency: foundation,
);
```

UI widgets should receive Domain-facing objects such as
`PlaybackControllerContract`, `PlaybackPageContract`,
`PlaybackStateSnapshot`, and `PlaybackCapabilityMatrix`. UI widgets must not
receive `MediaKitMpvBinding`, `MediaKitMpvBackendAdapter`, media_kit `Player`,
libmpv handles, provider clients, storage repositories, streaming engines, or
network implementations.

## Playback Source Handoff

The UI-owned file picker may produce a platform local path or file URI. The app
integration layer must convert that selection into Domain/Playback source
values before opening playback:

```dart
final PlaybackSourceHandoffResult prepared =
    const LocalPlaybackSourceHandoff().prepare(
  PlaybackSourceHandoffInput.localMediaIdentity(localMediaIdentity),
);

if (prepared.isSuccess) {
  await playerCore.controller.open(prepared.source!);
}
```

For local files, the prepared source is `LocalFilePlaybackSource`. For future
BT streaming, the integration layer must use playback-owned
`PlaybackVirtualStreamDescriptor` or `VirtualStreamPlaybackSource` values. It
must not pass streaming snapshots, platform file handles, media_kit `Media`
objects, storage rows, provider records, or UI selection state directly into
the player runtime.

## Lifecycle Observation

UI state should be derived from `PlaybackControllerContract.currentState` and
`PlaybackStateObserver`.

Expected local-file command flow:

1. Prepare source through handoff.
2. Call `controller.open(source)`.
3. Observe `opening`, then `paused` on successful open.
4. Dispatch `play`, `pause`, `seek`, and `stop` through
   `PlaybackPageContract.dispatch(...)` or `PlaybackControllerContract`.
5. Render controls from `PlaybackPageContract.resolveSurface()` and the active
   capability matrix.

The UI should treat repeated state notifications as snapshots. It should not
infer player backend state by inspecting concrete media_kit objects.

## Disposal Ownership

The app composition owner must dispose the player core when the playback
session or application lifetime ends:

```dart
await playerCore.dispose();
```

After disposal, `PlayerCoreRuntime` accessors throw `StateError`, while
commands already held through `PlaybackControllerContract` return normalized
disposed failures. UI widget disposal alone is not the runtime cleanup
boundary; the composition owner must dispose the runtime object.

## Error Contract

Playback failures are typed contract values:

- `PlaybackSourceHandoffFailure` for source preparation failures.
- `PlaybackCommandResult.failure` and `PlaybackFailureKind` for runtime
  command failures.
- `PlaybackStateSnapshot.failureReason` for user-facing state projection.
- `TrackSwitchResult.unsupported(...)` for track operations hidden by
  capability gates.

The UI may display `failureReason` or a mapped message from the failure kind,
but it must not parse concrete backend exception strings or branch on
media_kit/libmpv-specific error types.

## Smoke Gate

Before UI work is joined, run the core-owned smoke gate documented in
`docs/player-smoke-gate.md`. After UI work is joined, use the same packaging
script against the real Windows release directory and keep UI smoke separate
from core runtime validation.
