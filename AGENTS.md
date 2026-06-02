<!-- REPOSITORY-BASELINE:START -->
# Active Workflow Authority

OpenSpec is now the active workflow authority for this project. Use OpenSpec proposal, apply, validate, and archive flows for new work.

The Trellis block below is retained as legacy context because `.trellis/` still contains historical workflow, task, spec, and workspace material. Do not treat Trellis as the primary workflow unless a future explicit change re-enables it.

<!-- REPOSITORY-BASELINE:END -->

<!-- TRELLIS:START -->
# Trellis Instructions

These instructions are for AI assistants working in this project.

This project is managed by Trellis. The working knowledge you need lives under `.trellis/`:

- `.trellis/workflow.md` — development phases, when to create tasks, skill routing
- `.trellis/spec/` — package- and layer-scoped coding guidelines (read before writing code in a given layer)
- `.trellis/workspace/` — per-developer journals and session traces
- `.trellis/tasks/` — active and archived tasks (PRDs, research, jsonl context)

If a Trellis command is available on your platform (e.g. `/trellis:finish-work`, `/trellis:continue`), prefer it over manual steps. Not every platform exposes every command.

If you're using Codex or another agent-capable tool, additional project-scoped helpers may live in:
- `.agents/skills/` — reusable Trellis skills
- `.codex/agents/` — optional custom subagents

Managed by Trellis. Edits outside this block are preserved; edits inside may be overwritten by a future `trellis update`.

<!-- TRELLIS:END -->

# PROJECT KNOWLEDGE BASE

## OVERVIEW

Celesteria (代号 1017) — 端侧优先的跨平台 ACG 播放器。Flutter/Dart 前端 + MPV/native 后端，Provider/Adapter 扩展体系。当前处于 Phase 0 规划阶段，无源代码目录。

## STRUCTURE

```
pkpk/
├── .agents/skills/    # 10 Trellis skills (before-dev, brainstorm, check, etc.)
├── .codex/            # Codex agents + hooks config
├── .gemini/           # Gemini agents + commands + hooks
├── .sisyphus/         # Sisyphus continuation state
├── .trellis/          # Workflow engine (workflow.md, spec/, tasks/, workspace/)
│   ├── spec/backend/  # Backend guidelines (placeholder — "To fill")
│   ├── spec/frontend/ # Frontend guidelines (placeholder — "To fill")
│   ├── spec/guides/   # Cross-layer + code-reuse thinking guides
│   └── scripts/       # Python CLI (task.py, get_context.py, add_session.py, etc.)
└── docs/              # Architecture plan (celesteria-architecture-plan.md)
```

## WHERE TO LOOK

| Task | Location |
|------|----------|
| Architecture decisions | `docs/celesteria-architecture-plan.md` |
| Workflow phases & skill routing | `.trellis/workflow.md` |
| Backend coding rules | `.trellis/spec/backend/index.md` → links to sub-guides |
| Frontend coding rules | `.trellis/spec/frontend/index.md` → links to sub-guides |
| Cross-layer thinking | `.trellis/spec/guides/cross-layer-thinking-guide.md` |
| Code reuse patterns | `.trellis/spec/guides/code-reuse-thinking-guide.md` |
| Active task context | `.trellis/tasks/{MM-DD-name}/prd.md` |
| Session logs | `.trellis/workspace/{developer}/journal-*.md` |
| Trellis CLI help | `python ./.trellis/scripts/task.py --help` |

## CONVENTIONS

- Trellis 管理所有开发流程：brainstorm → plan → implement → check → commit
- spec 文件全部 "To fill" —— 实际编码规则待项目源代码建立后回填
- `python ./.trellis/scripts/` 是唯一 CLI 入口；不要绕过脚本直接操作 .trellis 内部文件
- spec 文档语言：English（per `.trellis/spec/*/index.md`）
- 架构文档用中文，代码和 spec 用英文
- Windows 环境：PowerShell 5.1，不支持 `&&` 链式命令，用 `;` 或分步执行

## ANTI-PATTERNS (THIS PROJECT)

- UI 不得直接依赖 MPV/VLC/Bangumi/弹弹play/libtorrent/yuc.wiki —— 必须通过 PlayerAdapter / Provider / FeedSource 扩展
- 在线源解析不得成为 Core 播放闭环前提
- 验证码禁止自动破解，只支持手动完成后同源会话回填
- yuc.wiki 不作为特殊抓取源 —— 只是 RSS Engine 的一个 FeedSource
- 不要把播放页 UI 当项目起点 —— 先冻结 Step 1-4 架构地基
- iOS 不承诺长期后台 BT 下载

## UNIQUE STYLES

- 8 层架构隔离：UI / Domain / Playback / Provider / Gateway / Storage / Streaming / Network
- 每层只暴露接口，具体实现通过 Adapter/Provider/Profile 接入
- CapabilityMatrix 声明所有能力，UI 只展示当前环境支持的功能
- 音画同步红线：A/V drift < 40ms，超过 120ms 必须降级；降级链 Anime4K Ultra → … → 关闭超分
- 所有高级渲染接入 FrameBudgetManager + AVSyncGuard + 诊断中心

## COMMANDS

```bash
# Trellis workflow
python ./.trellis/scripts/task.py create "<title>" --slug <name>
python ./.trellis/scripts/task.py start <task-dir>
python ./.trellis/scripts/task.py finish
python ./.trellis/scripts/get_context.py --mode packages
python ./.trellis/scripts/get_context.py --mode phase --step 1.1

# Developer identity
python ./.trellis/scripts/init_developer.py <your-name>
```

## NOTES

- 项目无源代码目录，处于 Phase 0 规划期；首批实施应严格限定 Step 1-4
- `.trellis/spec/` 所有 guideline 文件为 placeholder，需在代码落地后从实际代码库回填
- 不是 git 仓库（尚未初始化）
- 多平台 AI 工具配置共存：OpenCode (.opencode/) + Codex (.codex/) + Gemini (.gemini/) + Trellis (.trellis/)
- 发布切线：MVP = Step 1-17，差异化 = Step 1-21，高级播放 = Step 1-25，完整 = Step 1-30
