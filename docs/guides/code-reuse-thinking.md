# Code Reuse Thinking

Source: extracted from `.trellis/spec/guides/code-reuse-thinking-guide.md` on 2026-06-02.

## Purpose

Duplicated logic is a common source of inconsistent behavior. In Celesteria, duplication is especially risky around adapters, providers, capability handling, diagnostics, cache invalidation, and network policy because similar-looking code can silently diverge across layers.

Search before adding new code. Reuse or extend established contracts when they already express the behavior.

## Search First

Before writing a new function, adapter, model, checker, constant, or helper, search for:

- similar names
- similar domain terms
- existing contracts or adapters
- repeated constants
- prior validation/check scripts
- existing OpenSpec specs or docs that describe the behavior

On this Windows environment, use the fastest available search tool. If `rg` is not installed, use PowerShell, `findstr`, or direct file reads.

## Questions Before Adding Code

| Question | If yes |
|---|---|
| Does a similar function or contract exist? | Use it or extend it. |
| Is this pattern already used in another layer? | Follow the established shape unless the new case is materially different. |
| Could this become a shared utility or interface? | Put it in the layer that owns the concept. |
| Am I copying code from another file? | Stop and extract or parameterize if the behavior must stay identical. |
| Is the same constant defined elsewhere? | Create or reuse a single source of truth. |

## Common Duplication Patterns

### Copy-Paste Functions

Bad: copying provider validation or diagnostics formatting into a second adapter.

Good: centralize the shared behavior in the boundary that owns it, then call it from both paths.

### Similar Components Or Contracts

Bad: creating a new capability shape that is 80 percent identical to an existing one.

Good: extend the existing contract with a clear variant only when the difference is real.

### Repeated Constants

Bad: hardcoding drift thresholds, cache keys, capability names, or network policy names in multiple files.

Good: define constants once in the owning package or contract and import them.

## When To Abstract

Abstract when:

- the same behavior appears three or more times
- the logic is complex enough to contain bugs
- the behavior must remain consistent across adapters or layers
- multiple future implementations will need the same contract

Do not abstract when:

- there is only one use
- the code is a trivial one-liner
- the abstraction would obscure a domain rule
- two snippets look similar but represent different concepts

## After Batch Modifications

When similar changes were made across multiple files:

- [ ] Review whether every intended instance was changed.
- [ ] Search for missed variants.
- [ ] Check whether the common behavior should be a shared helper, interface, or constant.
- [ ] Run the relevant validation command or checker.

## Asymmetric Mechanisms Producing The Same Output

One high-risk duplication pattern is when two different mechanisms must produce the same file set or contract set. For example, one path may derive outputs automatically while another path lists them manually.

Symptoms:

- one workflow works but another creates files at old paths
- one platform updates but another retains stale routing
- a checker passes for fresh generation but fails for upgrade or migration

Prevention:

- [ ] Search for every code path that references the old structure.
- [ ] If one path is auto-derived and another is manually listed, update both.
- [ ] Add a regression or validation check that compares outputs from both mechanisms when practical.

## Celesteria-Specific Reuse Bias

- Prefer existing Provider/Adapter/Profile/Capability contracts over new one-off shapes.
- Prefer gateway and network policy helpers over direct external-service calls.
- Prefer diagnostics events shared by subsystem over per-feature logging formats.
- Prefer OpenSpec specs and docs as durable contract references over session-local notes.
