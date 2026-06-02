# Cross-Layer Thinking

Source: extracted from `.trellis/spec/guides/cross-layer-thinking-guide.md` on 2026-06-02.

## Purpose

Most integration bugs appear at layer boundaries, not inside a single layer. Celesteria is especially sensitive to this because the architecture intentionally separates UI, Domain, Playback, Provider, Gateway, Storage, Streaming, and Network.

Before changing a feature that crosses layers, map the complete data flow and define every boundary contract explicitly.

## Data Flow Checklist

For a feature, write the path in this shape:

```text
Source -> Transform -> Store -> Retrieve -> Transform -> Display
```

For every step, answer:

- What shape is the data in here?
- What can be null, empty, stale, partial, or invalid?
- Which layer owns validation?
- Which layer owns error translation?
- Which layer is allowed to know about the upstream implementation detail?

## Boundary Questions

| Boundary | Common risk | Required decision |
|---|---|---|
| UI to Domain | UI assumes provider/player/storage details | Domain contract exposed through stable interfaces only |
| Domain to Provider/Gateway | Provider result shapes drift | Gateway normalizes and validates provider output |
| Playback to UI | UI assumes concrete player backend | UI reads capabilities and state, not MPV/VLC implementation details |
| Storage to Domain | Stored schema leaks into domain model | Storage adapter owns persistence shape conversion |
| Network to Provider | Auth, rate limits, and challenges become ad hoc | Network policy and challenge/session handling stay centralized |
| Streaming to Playback | Download state is treated as direct playback truth | Streaming exposes capability/status contracts instead of backend internals |

## Common Mistakes

### Implicit Format Assumptions

Bad: assuming a provider returns a date, episode id, or image URL in the shape a UI widget wants.

Good: normalize at the boundary and make the target contract explicit.

### Scattered Validation

Bad: validating the same provider payload in UI, domain service, and storage.

Good: validate at the ingestion boundary, then carry typed/normalized data forward.

### Leaky Abstractions

Bad: UI knows about MPV, VLC, Bangumi, Dandanplay, libtorrent, yuc.wiki, raw RSS parser details, or database tables.

Good: UI depends on domain-facing contracts, capability declarations, and user-intent models.

## Celesteria Boundary Rules

- UI must not directly depend on MPV/VLC/Bangumi/Dandanplay/libtorrent/yuc.wiki.
- yuc.wiki is an RSS `FeedSource`, not a privileged special-case scraping provider.
- Online source parsing must not become a core playback prerequisite.
- Manual challenge completion and same-origin session backfill belong in the network/provider boundary, not in UI shortcuts.
- Advanced playback capabilities must be declared and guarded by capability/profile contracts before UI exposes them.
- Diagnostics should observe cross-layer events without becoming a hidden dependency path.

## Before Implementation

- [ ] The complete data flow is mapped.
- [ ] Every layer boundary is named.
- [ ] Input and output formats are explicit at each boundary.
- [ ] Validation ownership is assigned once.
- [ ] Error ownership is assigned once.
- [ ] UI-facing behavior is expressed through domain contracts or capability declarations.

## After Implementation

- [ ] Edge cases are tested or reasoned through: null, empty, invalid, stale, partial, and unsupported capability.
- [ ] Data survives a round trip where storage or cache is involved.
- [ ] Error states remain visible to diagnostics.
- [ ] No layer imports or references a concrete implementation from a non-neighbor layer.

## When To Create Flow Documentation

Create dedicated flow documentation when a feature spans three or more layers, changes external data format handling, introduces a provider/player/streaming adapter, or has already produced boundary bugs.
