import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/elaina_theme.dart';

class HotUpdatesCarousel extends StatefulWidget {
  const HotUpdatesCarousel({
    super.key,
    this.autoScroll = true,
    this.items = const <HotUpdateItem>[],
    this.onOpenDetail,
  });

  final bool autoScroll;
  final List<HotUpdateItem> items;
  final ValueChanged<String>? onOpenDetail;

  @override
  State<HotUpdatesCarousel> createState() => _HotUpdatesCarouselState();
}

final class HotUpdateItem {
  const HotUpdateItem({
    required this.subjectId,
    required this.title,
    required this.tag,
    required this.description,
    required this.symbol,
    this.coverUri,
  });

  final String subjectId;
  final String title;
  final String tag;
  final String description;
  final String symbol;
  final Uri? coverUri;
}

class _HotUpdatesCarouselState extends State<HotUpdatesCarousel> {
  static const double _compactWidthBreakpoint = 640;
  static const double _regularImageWidth = 300;
  static const double _compactImageWidth = 160;
  static const double _regularContentPadding = 40;
  static const double _compactContentPadding = 20;
  static const double _regularTitleSize = 48;
  static const double _compactTitleSize = 28;
  static const double _regularActionGap = 32;
  static const double _compactActionGap = 20;
  static const int _regularDescriptionLines = 3;
  static const int _compactDescriptionLines = 2;

  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;

  static const List<HotUpdateItem> _fallbackItems = <HotUpdateItem>[
    HotUpdateItem(
      subjectId: 'fallback-cyber-overload',
      title: '赛博超载',
      tag: '精选发布',
      description: '在霓虹灯闪烁的新东京街道上体验终极的高能冒险。同步率正在超出正常参数。网络等待着您的命令。',
      symbol: 'CB',
    ),
    HotUpdateItem(
      subjectId: 'fallback-prismatic-resonance',
      title: '棱镜共鸣',
      tag: '最新更新',
      description: '探索光与影的交界处。最新章节现已上线，揭开隐藏在棱镜背后的秘密。同步您的意识，准备迎接挑战。',
      symbol: 'PR',
    ),
  ];

  List<HotUpdateItem> get _items =>
      widget.items.isEmpty ? _fallbackItems : widget.items;

  @override
  void initState() {
    super.initState();
    if (widget.autoScroll) {
      _startAutoScroll();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      if (!_pageController.hasClients) return;
      _nextPage();
    });
  }

  void _nextPage() {
    final int itemCount = _items.length;
    if (itemCount == 0) return;
    if (_currentPage < itemCount - 1) {
      _currentPage++;
    } else {
      _currentPage = 0;
    }
    _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    final int itemCount = _items.length;
    if (itemCount == 0) return;
    if (_currentPage > 0) {
      _currentPage--;
    } else {
      _currentPage = itemCount - 1;
    }
    _pageController.animateToPage(
      _currentPage,
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ElainaTheme.of(context);
    final List<HotUpdateItem> items = _items;
    final bool hasProvidedItems = widget.items.isNotEmpty;

    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 400,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: items.length,
            itemBuilder: (context, index) {
              final HotUpdateItem item = items[index];
              return LayoutBuilder(
                builder: (context, constraints) {
                  final bool compact =
                      constraints.maxWidth < _compactWidthBreakpoint;
                  final double imageWidth =
                      compact ? _compactImageWidth : _regularImageWidth;
                  final double contentPadding =
                      compact ? _compactContentPadding : _regularContentPadding;
                  final double titleSize =
                      compact ? _compactTitleSize : _regularTitleSize;
                  final double actionGap =
                      compact ? _compactActionGap : _regularActionGap;
                  final int descriptionLines = compact
                      ? _compactDescriptionLines
                      : _regularDescriptionLines;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24.0),
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      children: [
                        SizedBox(
                          width: imageWidth,
                          child: _HotUpdatePlaceholder(
                            symbol: item.symbol,
                            index: index,
                            coverUri: item.coverUri,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(contentPadding),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.2)),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    item.tag,
                                    style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  item.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.primary,
                                    fontSize: titleSize,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: theme.primary
                                            .withValues(alpha: 0.3),
                                        blurRadius: 10,
                                      )
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  item.description,
                                  maxLines: descriptionLines,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color:
                                        theme.onSurface.withValues(alpha: 0.8),
                                    fontSize: 16,
                                    height: 1.6,
                                  ),
                                ),
                                SizedBox(height: actionGap),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 12,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: hasProvidedItems
                                          ? () => widget.onOpenDetail
                                              ?.call(item.subjectId)
                                          : null,
                                      icon: const Icon(Icons.info_outline),
                                      label: const Text('查看详情'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFFFF2A5F),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                        ),
                                        elevation: 8,
                                        shadowColor: const Color(0xFFFF2A5F)
                                            .withValues(alpha: 0.5),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    OutlinedButton(
                                      onPressed: null,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: theme.primary,
                                        side: BorderSide(
                                            color: Colors.white
                                                .withValues(alpha: 0.2)),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 24, vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(24),
                                        ),
                                      ),
                                      child: const Text('Bangumi 排名'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),

        // Navigation Arrows
        Positioned(
          left: 20,
          child: _buildNavButton(Icons.chevron_left, _previousPage, theme),
        ),
        Positioned(
          right: 20,
          child: _buildNavButton(Icons.chevron_right, _nextPage, theme),
        ),
      ],
    );
  }

  Widget _buildNavButton(
      IconData icon, VoidCallback onPressed, ElainaThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
              color: theme.primary.withValues(alpha: 0.1), blurRadius: 10),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: theme.primary),
        onPressed: onPressed,
      ),
    );
  }
}

class _HotUpdatePlaceholder extends StatelessWidget {
  const _HotUpdatePlaceholder({
    required this.symbol,
    required this.index,
    this.coverUri,
  });

  final String symbol;
  final int index;
  final Uri? coverUri;

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    final List<List<Color>> palettes = <List<Color>>[
      <Color>[const Color(0xFFFF2A5F), theme.primary],
      <Color>[theme.secondary, const Color(0xFF7C3AED)],
    ];
    final List<Color> colors = palettes[index % palettes.length];
    final Uri? imageUri = coverUri;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        image: imageUri == null
            ? null
            : DecorationImage(
                image: NetworkImage(imageUri.toString()),
                fit: BoxFit.cover,
              ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Icon(
            Icons.auto_awesome,
            size: 180,
            color: Colors.white.withValues(alpha: 0.18),
          ),
          Center(
            child: Text(
              symbol,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 56,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
