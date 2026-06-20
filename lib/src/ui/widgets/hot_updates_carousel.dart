import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/elaina_theme.dart';

class HotUpdatesCarousel extends StatefulWidget {
  const HotUpdatesCarousel({
    super.key,
    this.autoScroll = true,
  });

  final bool autoScroll;

  @override
  State<HotUpdatesCarousel> createState() => _HotUpdatesCarouselState();
}

class _HotUpdatesCarouselState extends State<HotUpdatesCarousel> {
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;

  final List<Map<String, String>> _items = const [
    {
      'title': '赛博超载',
      'tag': '精选发布',
      'description': '在霓虹灯闪烁的新东京街道上体验终极的高能冒险。同步率正在超出正常参数。网络等待着您的命令。',
      'symbol': 'CB',
    },
    {
      'title': '棱镜共鸣',
      'tag': '最新更新',
      'description': '探索光与影的交界处。最新章节现已上线，揭开隐藏在棱镜背后的秘密。同步您的意识，准备迎接挑战。',
      'symbol': 'PR',
    },
  ];

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
    if (_currentPage < _items.length - 1) {
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
    if (_currentPage > 0) {
      _currentPage--;
    } else {
      _currentPage = _items.length - 1;
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
            itemCount: _items.length,
            itemBuilder: (context, index) {
              final item = _items[index];
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24.0),
                  color: Colors.white.withValues(alpha: 0.05),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    // Image Side
                    SizedBox(
                      width: 300,
                      child: _HotUpdatePlaceholder(
                        symbol: item['symbol']!,
                        index: index,
                      ),
                    ),
                    // Content Side
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2)),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Text(
                                item['tag']!,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              item['title']!,
                              style: TextStyle(
                                color: theme.primary,
                                fontSize: 48,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(
                                    color: theme.primary.withValues(alpha: 0.3),
                                    blurRadius: 10,
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              item['description']!,
                              style: TextStyle(
                                color: theme.onSurface.withValues(alpha: 0.8),
                                fontSize: 16,
                                height: 1.6,
                              ),
                            ),
                            const SizedBox(height: 32),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(Icons.add_circle),
                                  label: const Text('添加到追番'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF2A5F),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                    elevation: 8,
                                    shadowColor: const Color(0xFFFF2A5F)
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                OutlinedButton(
                                  onPressed: () {},
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: theme.primary,
                                    side: BorderSide(
                                        color: Colors.white
                                            .withValues(alpha: 0.2)),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 24, vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(24),
                                    ),
                                  ),
                                  child: const Text('查看详情'),
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
  });

  final String symbol;
  final int index;

  @override
  Widget build(BuildContext context) {
    final ElainaThemeData theme = ElainaTheme.of(context);
    final List<List<Color>> palettes = <List<Color>>[
      <Color>[const Color(0xFFFF2A5F), theme.primary],
      <Color>[theme.secondary, const Color(0xFF7C3AED)],
    ];
    final List<Color> colors = palettes[index % palettes.length];

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
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
