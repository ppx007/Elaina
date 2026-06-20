import 'package:flutter/material.dart';

import '../../domain/rss/rss_engine_runtime.dart';
import '../theme/elaina_theme.dart';

class RssPage extends StatefulWidget {
  const RssPage({
    super.key,
    required this.rssEngineRuntime,
  });

  final RssEngineRuntime rssEngineRuntime;

  @override
  State<RssPage> createState() => _RssPageState();
}

class _RssPageState extends State<RssPage> implements RssEngineRuntimeObserver {
  late RssEngineRuntimeSnapshot _snapshot;
  final Map<String, bool> _feedActivationStates = <String, bool>{};
  bool _isRefreshingRegistry = false;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.rssEngineRuntime.currentSnapshot;
    widget.rssEngineRuntime.addObserver(this);
    _refreshRegistry();
    _loadActivations();
  }

  @override
  void dispose() {
    widget.rssEngineRuntime.removeObserver(this);
    super.dispose();
  }

  @override
  void onRssEngineRuntimeSnapshot(RssEngineRuntimeSnapshot snapshot) {
    if (mounted) {
      setState(() {
        _snapshot = snapshot;
      });
      _loadActivations();
    }
  }

  Future<void> _refreshRegistry() async {
    setState(() {
      _isRefreshingRegistry = true;
    });
    await widget.rssEngineRuntime.listSources();
    if (mounted) {
      setState(() {
        _isRefreshingRegistry = false;
      });
    }
  }

  Future<void> _loadActivations() async {
    if (mounted) {
      for (final source in _snapshot.sources) {
        final bool enabled = await widget.rssEngineRuntime
            .isAutoDownloadEnabled(source.id.value);
        if (mounted) {
          setState(() {
            _feedActivationStates[source.id.value] = enabled;
          });
        }
      }
    }
  }

  Future<void> _toggleAutoDownload(String sourceIdValue, bool enabled) async {
    await widget.rssEngineRuntime
        .setAutoDownloadEnabled(sourceIdValue, enabled);
    if (mounted) {
      setState(() {
        _feedActivationStates[sourceIdValue] = enabled;
      });
    }
  }

  Future<void> _refreshSource(String idValue) async {
    await widget.rssEngineRuntime.refreshSourceById(idValue);
  }

  Future<void> _addNewFeed() async {
    final ElainaThemeData theme = ElainaTheme.of(context);
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return _AddFeedDialog(
          theme: theme,
          rssEngineRuntime: widget.rssEngineRuntime,
          refreshRegistry: _refreshRegistry,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    final bool isBusy = _snapshot.status == RssEngineRuntimeStatus.refreshing ||
        _isRefreshingRegistry;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Text(
                'RSS 订阅中心',
                style: TextStyle(
                  color: theme.onSurface,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: <Widget>[
                  IconButton(
                    icon: isBusy
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.primary.withValues(alpha: 0.7),
                            ),
                          )
                        : const Icon(Icons.refresh_outlined),
                    color: theme.primary,
                    onPressed: isBusy ? null : _refreshRegistry,
                    tooltip: '刷新源列表',
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _addNewFeed,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('添加订阅'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primary,
                      foregroundColor: theme.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main Columns Layout
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Left Column - Subscribed Channels
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.border),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '已订阅的 RSS 源',
                          style: TextStyle(
                            color: theme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Divider(height: 24, color: theme.border),
                        Expanded(
                          child: _snapshot.sources.isEmpty
                              ? Center(
                                  child: Text(
                                    '暂无订阅，请点击“添加订阅”按钮。',
                                    style: TextStyle(
                                      color: theme.onBackground
                                          .withValues(alpha: 0.5),
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _snapshot.sources.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    final source = _snapshot.sources[index];
                                    final bool autoDl = _feedActivationStates[
                                            source.id.value] ??
                                        false;

                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 6.0),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: theme.onBackground
                                            .withValues(alpha: 0.03),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                            color: theme.border
                                                .withValues(alpha: 0.5)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: <Widget>[
                                              Expanded(
                                                child: Text(
                                                  source.displayName,
                                                  style: TextStyle(
                                                    color: theme.onSurface,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 14,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.sync,
                                                    size: 16),
                                                color: theme.secondary,
                                                onPressed: () => _refreshSource(
                                                    source.id.value),
                                                tooltip: '手动同步此源',
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            source.uri.toString(),
                                            style: TextStyle(
                                              color: theme.onBackground
                                                  .withValues(alpha: 0.5),
                                              fontSize: 11,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: <Widget>[
                                              Text(
                                                '自动下载策略',
                                                style: TextStyle(
                                                  color: theme.onSurface
                                                      .withValues(alpha: 0.8),
                                                  fontSize: 12,
                                                ),
                                              ),
                                              Switch(
                                                value: autoDl,
                                                activeThumbColor: theme.primary,
                                                onChanged: (bool val) =>
                                                    _toggleAutoDownload(
                                                        source.id.value, val),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 24),

                // Right Column - Catalog Listings
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.border),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          '季度更新索引 (${_snapshot.acceptedItems.length})',
                          style: TextStyle(
                            color: theme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 24, color: Colors.white10),
                        Expanded(
                          child: _snapshot.acceptedItems.isEmpty
                              ? Center(
                                  child: Text(
                                    '索引库为空。同步上方订阅源以拉取最新列表。',
                                    style: TextStyle(
                                      color: theme.onBackground
                                          .withValues(alpha: 0.5),
                                      fontSize: 13,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _snapshot.acceptedItems.length,
                                  itemBuilder:
                                      (BuildContext context, int index) {
                                    final FeedItem item =
                                        _snapshot.acceptedItems[index];

                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 6.0),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.03),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: theme.border
                                                .withValues(alpha: 0.5)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(
                                            item.title,
                                            style: TextStyle(
                                              color: theme.onSurface,
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              height: 1.4,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: <Widget>[
                                              if (item.categories.isNotEmpty)
                                                Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: theme.primary
                                                        .withValues(alpha: 0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            6),
                                                  ),
                                                  child: Text(
                                                    item.categories.first,
                                                    style: TextStyle(
                                                      color: theme.primary,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                )
                                              else
                                                const SizedBox.shrink(),
                                              Text(
                                                item.publishedAt != null
                                                    ? '${item.publishedAt!.month}月${item.publishedAt!.day}日'
                                                    : '未知发布日期',
                                                style: TextStyle(
                                                  color: theme.onBackground
                                                      .withValues(alpha: 0.5),
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AddFeedDialog extends StatefulWidget {
  const _AddFeedDialog({
    required this.theme,
    required this.rssEngineRuntime,
    required this.refreshRegistry,
  });

  final ElainaThemeData theme;
  final RssEngineRuntime rssEngineRuntime;
  final Future<void> Function() refreshRegistry;

  @override
  State<_AddFeedDialog> createState() => _AddFeedDialogState();
}

class _AddFeedDialogState extends State<_AddFeedDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _urlController;
  FeedFormat _selectedFormat = FeedFormat.rss;
  String? _nameErrorText;
  String? _urlErrorText;
  String? _formErrorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _urlController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: widget.theme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
        side: BorderSide(color: widget.theme.border),
      ),
      title: Text(
        '订阅新 RSS 源',
        style: TextStyle(
            color: widget.theme.onSurface, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          TextField(
            controller: _nameController,
            style: TextStyle(color: widget.theme.onSurface),
            onChanged: (_) {
              if (_nameErrorText != null || _formErrorText != null) {
                setState(() {
                  _nameErrorText = null;
                  _formErrorText = null;
                });
              }
            },
            decoration: InputDecoration(
              labelText: '订阅源名称',
              errorText: _nameErrorText,
              labelStyle: TextStyle(
                  color: widget.theme.onBackground.withValues(alpha: 0.6)),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: widget.theme.border)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: widget.theme.primary)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _urlController,
            style: TextStyle(color: widget.theme.onSurface),
            onChanged: (_) {
              if (_urlErrorText != null || _formErrorText != null) {
                setState(() {
                  _urlErrorText = null;
                  _formErrorText = null;
                });
              }
            },
            decoration: InputDecoration(
              labelText: 'RSS URL 地址',
              errorText: _urlErrorText,
              labelStyle: TextStyle(
                  color: widget.theme.onBackground.withValues(alpha: 0.6)),
              enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: widget.theme.border)),
              focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: widget.theme.primary)),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Text(
                '订阅源格式：',
                style: TextStyle(color: widget.theme.onSurface, fontSize: 13),
              ),
              const SizedBox(width: 8),
              DropdownButton<FeedFormat>(
                value: _selectedFormat,
                dropdownColor: widget.theme.surface,
                style: TextStyle(color: widget.theme.onSurface),
                underline: Container(
                  height: 1,
                  color: widget.theme.primary,
                ),
                items: const <DropdownMenuItem<FeedFormat>>[
                  DropdownMenuItem<FeedFormat>(
                    value: FeedFormat.rss,
                    child: Text('RSS 格式'),
                  ),
                  DropdownMenuItem<FeedFormat>(
                    value: FeedFormat.atom,
                    child: Text('Atom 格式'),
                  ),
                ],
                onChanged: (FeedFormat? value) {
                  if (value != null) {
                    setState(() {
                      _selectedFormat = value;
                    });
                  }
                },
              ),
            ],
          ),
          if (_formErrorText != null) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              _formErrorText!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            '取消',
            style: TextStyle(
                color: widget.theme.onBackground.withValues(alpha: 0.6)),
          ),
        ),
        ElevatedButton(
          onPressed: _isSubmitting
              ? null
              : () async {
                  final String name = _nameController.text.trim();
                  final String url = _urlController.text.trim();
                  final Uri? parsedUri = _parseFeedUrl(url);
                  final String? nameError = name.isEmpty ? '请输入订阅源名称' : null;
                  final String? urlError = _feedUrlError(url, parsedUri);
                  if (nameError != null ||
                      urlError != null ||
                      parsedUri == null) {
                    setState(() {
                      _nameErrorText = nameError;
                      _urlErrorText = urlError;
                      _formErrorText = null;
                    });
                    return;
                  }

                  setState(() {
                    _isSubmitting = true;
                    _nameErrorText = null;
                    _urlErrorText = null;
                    _formErrorText = null;
                  });

                  final result =
                      await widget.rssEngineRuntime.registerSourceParams(
                    id: 'source-${Uri.encodeComponent(parsedUri.toString())}',
                    displayName: name,
                    uri: parsedUri,
                    format: _selectedFormat,
                  );
                  if (!mounted) return;
                  setState(() {
                    _isSubmitting = false;
                  });
                  if (!result.isSuccess) {
                    setState(() {
                      _formErrorText =
                          result.failure?.message ?? '订阅源注册失败，请稍后重试。';
                    });
                    return;
                  }

                  await widget.refreshRegistry();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.theme.primary,
            foregroundColor: widget.theme.background,
          ),
          child: Text(_isSubmitting ? '订阅中…' : '订阅'),
        ),
      ],
    );
  }

  Uri? _parseFeedUrl(String url) => Uri.tryParse(url);

  String? _feedUrlError(String url, Uri? parsedUri) {
    if (url.isEmpty) return '请输入 RSS URL 地址';
    if (parsedUri == null) return '请输入有效的 RSS URL';
    final String scheme = parsedUri.scheme.toLowerCase();
    if ((scheme != 'http' && scheme != 'https') || parsedUri.host.isEmpty) {
      return 'RSS URL 必须是 http 或 https 地址';
    }
    return null;
  }
}
