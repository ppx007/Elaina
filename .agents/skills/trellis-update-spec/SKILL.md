---
name: trellis-update-spec
description: "Updates supplemental .trellis/spec convention notes only after deciding the knowledge does not belong in OpenSpec. OpenSpec remains the authoritative spec system."
---

# Update Supplemental Trellis Specs

Use this skill when you learned a durable local implementation convention that
helps future work but does not define product behavior or cross-layer contract.

## Authority Rule

Update OpenSpec first when the knowledge affects:

- user-visible behavior
- provider, gateway, storage, playback, network, streaming, or UI contracts
- validation or error behavior that tests should enforce
- public commands, settings, schemas, or runtime capabilities

Use `.trellis/spec/` only for supplemental coding practices, testing heuristics,
and historical gotchas that support OpenSpec-backed implementation.

## Process

1. State what was learned and why it matters.
2. Decide whether it belongs in OpenSpec or Trellis.
3. If it belongs in Trellis, update the smallest relevant `.trellis/spec/**`
   file and its `index.md` if needed.
4. Keep the note concrete: affected files, correct pattern, forbidden pattern,
   and tests or checks that catch the mistake.

Do not write Trellis task journals or archive tasks from this skill.
