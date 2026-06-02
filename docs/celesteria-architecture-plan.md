# Celesteria 播放器架构推进计划 v20.4

软件名称：Celesteria

简称：1017

## 定位

Celesteria 是一个端侧优先的跨平台 ACG 播放器。核心能力包括 MPV 默认播放、多字幕与高级字幕、高级弹幕、Bangumi 元数据、弹弹play 弹幕、BT 边下边播、RSS 自动下载、季度新番订阅、Anime4K/MPV 画质增强、在线规则源扩展与诊断中心。

系统原则是：播放链路优先稳定，所有外部能力通过 Provider/Adapter/Profile 接入，避免把具体服务或播放器写死在业务层。

## 全局原则

1. UI 不直接依赖 MPV、VLC、Bangumi、弹弹play、libtorrent、yuc.wiki。
2. 播放器通过 `PlayerAdapter` 扩展。
3. 外部数据通过 `Provider` 扩展。
4. RSS 通过 `FeedSource` + `FeedConsumer` 扩展。
5. 缓存、限流、重试全部走 `ProviderGateway`。
6. 每个模块保留 Adapter / Provider / Profile / FeatureFlag 扩展点。
7. 所有能力由 `Capability Matrix` 声明，UI 只展示当前环境支持的功能。
8. 所有高级渲染功能必须接入 `FrameBudgetManager`、`AVSyncGuard` 和诊断中心。

## 核心架构

```text
Flutter UI
├─ 首页
├─ 媒体库
├─ 视频详情页
├─ 播放页
├─ 下载页
├─ RSS 页
├─ 规则源页
├─ 设置页
└─ 诊断页

Domain Services
├─ PlaybackService
├─ DownloadService
├─ DanmakuService
├─ SubtitleService
├─ MetadataService
├─ BangumiMatchService
├─ SeasonalAnimeService
├─ RuleSourceService
├─ RssService
└─ CacheService

Playback Layer
├─ PlayerOrchestrator
├─ CapabilityMatrix
├─ MPV Adapter
├─ VLC Adapter
├─ Platform Adapter
├─ VideoEnhancementPipeline
├─ AVSyncGuard
├─ SubtitleRenderer
├─ DanmakuRenderer
├─ TimelineOverlay
└─ FrameBudgetManager

Streaming Layer
├─ VirtualMediaStream
├─ BTStreamingService
├─ PiecePriorityScheduler
├─ RangeServer / PipeServer
└─ BufferedRangeTracker

Provider Layer
├─ BangumiProvider
├─ DandanplayProvider
├─ SubtitleProvider
├─ OnlineSourceProvider
├─ RSSProvider
├─ FeedConsumer Registry
└─ TraceProvider

Gateway Layer
├─ ProviderGateway
├─ RateLimiter
├─ RequestDeduplicator
├─ RetryScheduler
├─ HttpCache
├─ SemanticCache
├─ NegativeCache
└─ CacheInvalidationBus

Storage Layer
├─ SQLite metadata DB
├─ Blob cache
├─ Media cache
├─ Torrent storage
└─ User settings

Network Layer
├─ System DNS
├─ Optional DoH/DoT
├─ Per-domain DNS policy
├─ SSRF guard
└─ Cookie/session isolation
```

## 用户体验红线

1. 功能不能混乱，每个页面只服务一个主任务。
2. 视频详情页负责理解作品和选择剧集，不展示播放器底层参数。
3. 播放页负责观看和播放控制，高级功能进入二级面板。
4. 下载页负责任务状态，RSS 页负责订阅规则，规则源页负责源管理与测试。
5. 视频详情页主按钮最多 2 个。
6. 集数卡片不堆叠多按钮，更多操作进入动作面板。
7. 高级功能默认折叠，技术参数不进入普通用户首层路径。
8. 所有异常状态必须能跳转到诊断页。

## 音画同步红线

超分是可选增强，音画同步是底线。

```text
基准时钟：音频 clock 优先
视频：跟随音频 PTS
字幕：跟随 PlayerClock
弹幕：跟随 PlayerClock，不使用独立 wall clock
```

质量门槛：

```text
正常播放 A/V drift：目标 < 40ms
短时负载波动：允许 < 80ms
超过 120ms：必须触发降级或恢复策略
掉帧持续增长：必须降级
超分切换后 2 秒内恢复稳定
```

降级顺序：

```text
Anime4K Ultra
→ Anime4K Quality
→ Anime4K Balanced
→ Anime4K Fast
→ MPV 内建 ewa_lanczossharp
→ MPV 内建 spline36
→ 关闭超分
```

## 分步落地 Plan

> 推荐首个实现切片：**Phase 0 / Step 1-4**。
>
> 不建议从播放器 UI、播放页交互或单一 Provider 接入直接开工。先冻结分层边界、本地存储、`ProviderGateway` 与 `CacheInvalidationBus`，再进入播放器 Core，可以显著降低后续播放、RSS、Provider、缓存一致性与诊断链路的返工风险。

### Phase 0：架构地基

| Step | 模块 | 交付 | 扩展点 |
|---|---|---|---|
| 1 | 项目分层 | UI / Domain / Playback / Provider / Gateway / Storage / Streaming / Network | 每层只暴露接口 |
| 2 | 本地存储 | SQLite、Blob cache、Media cache、Settings、Migration | schemaVersion 可迁移 |
| 3 | ProviderGateway | 去重、限流、重试、HTTP cache、负缓存 | 每个 Provider 注册 rate policy |
| 4 | CacheInvalidationBus | DanmakuPosted、BindingChanged、ProviderAuthChanged 等 | 新业务只加事件 |

### Phase 1：播放器 Core

| Step | 模块 | 交付 | 扩展点 |
|---|---|---|---|
| 5 | MPV Adapter | 本地文件 / HTTP / HLS 播放 | 可替换 media-kit/libmpv 实现 |
| 6 | Capability Matrix | 播放能力声明 | VLC/ExoPlayer/AVPlayer 补能力表 |
| 7 | 播放页基础 UI | 视频区、播放控制、进度条、更多面板 | 控件由能力矩阵动态显示 |
| 8 | 轨道管理 | 音轨、字幕轨读取与切换 | 后续支持章节轨、外挂轨 |

### Phase 2：字幕、弹幕、Bangumi

| Step | 模块 | 交付 | 扩展点 |
|---|---|---|---|
| 9 | 基础字幕 | SRT/VTT/ASS、外挂字幕扫描、offset | SubtitleParser 可插拔 |
| 10 | BangumiProvider | subject、episode、OAuth、进度同步 | MetadataProvider 可接其他源 |
| 11 | DandanplayProvider | match/search/comment、弹幕发送 | DanmakuProvider 可接更多弹幕源 |
| 12 | 基础弹幕 | 滚动/顶部/底部、屏蔽、密度 | Renderer 可替换 |

### Phase 3：详情页、媒体库、字幕源、季度新番

| Step | 模块 | 交付 | 扩展点 |
|---|---|---|---|
| 13 | 视频详情页 | 封面、简介、选集、继续播放、追番 | 数据来自 MetadataProvider |
| 14 | 媒体库 | 本地扫描、历史、绑定状态 | MediaScanner 可接 WebDAV/SMB/Jellyfin |
| 15 | SubtitleProvider | OpenSubtitles、本地字幕、缓存 | 新字幕源按 Provider 注册 |
| 16 | RSS Engine 基础 | FeedSource、FeedFetcher、FeedParser、FeedScheduler、去重 | RSS/Atom 均可扩展 |
| 17 | YucWiki RSS Seasonal Indexer | yuc.wiki RSS 订阅、SeasonalAnimeConsumer、季度条目、Bangumi 匹配队列 | 新季度源只加 FeedSource + Consumer |

YucWiki RSS 数据流：

```text
RSS Scheduler
  → 拉取 yuc.wiki RSS
  → FeedParser 解析 RSS/Atom
  → FeedItemDeduplicator 去重
  → SeasonalAnimeConsumer 消费 item
  → 标准化为 SeasonCatalogEntry
  → 写入 season_catalog_entry
  → 入队 BangumiMatchQueue
  → BangumiProvider 限流查询
  → 保存候选匹配
```

### Phase 4：BT 边下边播

| Step | 模块 | 交付 | 扩展点 |
|---|---|---|---|
| 18 | BT 任务核心 | magnet/torrent、metadata、文件列表、任务管理 | DownloadEngine 可替换 libtorrent |
| 19 | VirtualMediaStream | Range 读取、buffered ranges、piece map | 播放器只认虚拟流 |
| 20 | PiecePriorityScheduler | 当前窗口、seek 目标、首尾 piece 优先 | 策略 Profile 可切换 |
| 21 | TimelineOverlay | 进度、缓冲、BT 块、高能热力 | 时间轴 Layer 可增删 |

### Phase 5：高级播放

| Step | 模块 | 交付 | 扩展点 |
|---|---|---|---|
| 22 | VideoEnhancementPipeline | MPV scaler、HDR、deband、Anime4K preset | EnhancementProfile 可导入 |
| 23 | AVSyncGuard | A/V drift、掉帧、渲染延迟、自动降级 | 不同内核可实现监控适配 |
| 24 | 高级弹幕/字幕 | Matrix4 弹幕、双字幕、PGS、ASS 增强 | FeatureFlag 控制 |
| 25 | VLC fallback | VLC Adapter、失败切换、能力隐藏 | 后续加平台 Adapter |

### Phase 6：自动化与扩展

| Step | 模块 | 交付 | 扩展点 |
|---|---|---|---|
| 26 | RSS 自动下载 | 过滤规则、去重、自动加 BT | FeedConsumer 可复用 RSS Engine |
| 27 | 在线规则源 | XPath/CSS 搜索、详情、选集、播放解析 | RuleRuntime 可扩展 JS/WASM |
| 28 | WebView 验证回填 | challenge 检测、隔离 WebView、同源 Cookie 回填 | 每源独立 SessionProvider |
| 29 | DNS/网络策略 | per-domain DNS、DoH/DoT、SSRF 防护、代理 | NetworkPolicy 可按 Provider 覆盖 |
| 30 | 诊断中心 | 播放、BT、API、缓存、规则源、A/V sync | 诊断项注册式扩展 |

## 冻结点

```text
Step 1-4：架构冻结
Step 5-8：播放器 Core 冻结
Step 9-17：ACG 数据体验冻结
Step 18-21：BT 播放冻结
Step 22-25：高级播放冻结
Step 26-30：扩展能力冻结
```

## 发布切线

```text
MVP：Step 1-17
差异化版：Step 1-21
高级播放版：Step 1-25
完整扩展版：Step 1-30
```

## 关键约束

1. `yuc.wiki` 不作为特殊抓取源处理，而是 RSS Engine 的一个 `FeedSource`。
2. `SeasonalAnimeConsumer` 消费 yuc.wiki RSS item，再通过 `BangumiMatchQueue` 做限流匹配。
3. 用户确认的 Bangumi 绑定优先级永远高于自动匹配。
4. 在线源解析永远后置，不能成为 Core 播放闭环的前提。
5. 验证码只支持用户手动完成后的同源会话回填，不支持自动破解。
6. DNS 策略按域名和 Provider 配置，默认尊重系统 DNS。
7. iOS 不承诺长期后台 BT 下载；Android 后台下载必须使用前台服务；桌面可使用常驻任务。

## 首个执行切片说明

后续正式实施时，第一批任务应严格限定为 **Phase 0 / Step 1-4**：

1. **Step 1 — 项目分层**：先建立 UI / Domain / Playback / Provider / Gateway / Storage / Streaming / Network 的目录和接口边界，禁止跨层直连具体实现。
2. **Step 2 — 本地存储**：先落地 SQLite、Blob cache、Media cache、Settings 与迁移骨架，为播放记录、RSS 条目、缓存状态、诊断快照提供稳定承载。
3. **Step 3 — `ProviderGateway`**：统一外部 Provider 的去重、限流、重试、缓存与失败语义，避免 Bangumi、弹弹play、字幕源、RSS 拉取各自实现一套网络治理逻辑。
4. **Step 4 — `CacheInvalidationBus`**：先定义跨模块事件与缓存失效传播，再接入详情页、播放页、RSS、Bangumi 绑定、Provider 鉴权等上层功能。

只有在这 4 步完成后，才建议进入 `Phase 1` 的播放器 Core，包括 MPV Adapter、Capability Matrix 与播放页基础 UI。也就是说，**不要把播放页 UI 当成项目起点**。
