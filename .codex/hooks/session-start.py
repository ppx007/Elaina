#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Codex SessionStart hook for Elaina.

OpenSpec is the active workflow authority. This hook injects only a compact
pointer to the optional Trellis convention library so new sessions do not
mistake legacy Trellis task flow for the current development process.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def _should_skip_injection() -> bool:
    return (
        os.environ.get("TRELLIS_HOOKS") == "0"
        or os.environ.get("TRELLIS_DISABLE_HOOKS") == "1"
        or os.environ.get("CODEX_NON_INTERACTIVE") == "1"
    )


def _find_repo_root(start: Path) -> Path:
    current = start.resolve()
    while current != current.parent:
        if (current / "AGENTS.md").is_file() and (current / "openspec").is_dir():
            return current
        current = current.parent
    return start.resolve()


def _load_hook_input() -> dict:
    try:
        data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def _discover_spec_indexes(repo_root: Path) -> list[str]:
    spec_root = repo_root / ".trellis" / "spec"
    if not spec_root.is_dir():
        return []
    return [
        str(path.relative_to(repo_root)).replace("\\", "/")
        for path in sorted(spec_root.rglob("index.md"))
        if path.is_file()
    ]


def _build_context(repo_root: Path) -> str:
    spec_indexes = _discover_spec_indexes(repo_root)
    spec_lines = "\n".join(f"- {path}" for path in spec_indexes)
    if not spec_lines:
        spec_lines = "- No Trellis spec indexes found."

    return f"""<first-reply-notice>
On the first visible assistant reply in this session, begin with exactly one short Chinese sentence:
OpenSpec 是主流程，Trellis 仅作为辅助规范上下文。
Then continue directly with the user's request. This notice is one-shot.
</first-reply-notice>

<session-context>
This repository is OpenSpec-managed. Follow AGENTS.md, README.md, and openspec/specs as the active authority.
Trellis is supplemental context only: use .trellis/spec for local coding conventions when helpful, and do not create Trellis tasks, launch legacy Trellis agents, archive Trellis tasks, or write Trellis journals unless the user explicitly asks.
</session-context>

<validation>
- dart analyze
- dart run tools\\elaina_tool.dart check changed --scope Fast
- dart run tools\\elaina_tool.dart check module --module <name>
- dart run tools\\elaina_tool.dart check full
- openspec.cmd validate --all
</validation>

<trellis-spec-indexes>
{spec_lines}
</trellis-spec-indexes>

<ready>
Context loaded. Use OpenSpec and the latest user request as the workflow source of truth.
</ready>"""


def main() -> int:
    if _should_skip_injection():
        return 0

    hook_input = _load_hook_input()
    repo_root = _find_repo_root(Path(hook_input.get("cwd") or os.getcwd()))
    context = _build_context(repo_root)
    result = {
        "suppressOutput": True,
        "systemMessage": f"OpenSpec context injected ({len(context)} chars)",
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": context,
        },
        "additional_context": context,
    }
    print(json.dumps(result), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
