import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/elaina_theme.dart';

class HeroCarousel extends StatefulWidget {
  const HeroCarousel({
    super.key,
    this.autoScroll = true,
    this.items = const <HeroCarouselItem>[],
  });

  final bool autoScroll;
  final List<HeroCarouselItem> items;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

final class HeroCarouselItem {
  const HeroCarouselItem({
    required this.title,
    required this.symbol,
    this.coverUri,
    this.rankingSentence,
  });

  final String title;
  final String symbol;
  final Uri? coverUri;
  final String? rankingSentence;
}

class _HeroCarouselState extends State<HeroCarousel> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  final double _itemWidth = 500.0;
  final double _itemGap = 24.0;

  static const List<HeroCarouselItem> _fallbackItems = <HeroCarouselItem>[
    HeroCarouselItem(title: 'Stellar Echoes', symbol: 'SE'),
    HeroCarouselItem(title: 'Neon Protocol', symbol: 'NP'),
    HeroCarouselItem(title: 'Crimson Horizon', symbol: 'CH'),
    HeroCarouselItem(title: 'Prismatic Resonance', symbol: 'PR'),
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
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      if (!_scrollController.hasClients) return;

      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      final currentOffset = _scrollController.offset;
      final advanceAmount = _itemWidth + _itemGap;

      if (currentOffset >= maxScrollExtent - 10) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      } else {
        _scrollController.animateTo(
          currentOffset + advanceAmount,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ElainaTheme.of(context);
    final List<HeroCarouselItem> items =
        widget.items.isEmpty ? _fallbackItems : widget.items;

    return SizedBox(
      height: 400,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => SizedBox(width: _itemGap),
        itemBuilder: (context, index) {
          final HeroCarouselItem item = items[index];
          return Container(
            width: _itemWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              color: theme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _HeroPosterPlaceholder(
                  symbol: item.symbol,
                  index: index,
                  coverUri: item.coverUri,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.8),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(color: Colors.black54, blurRadius: 10)
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (item.rankingSentence != null) ...<Widget>[
                        Text(
                          item.rankingSentence!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.78),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            shadows: const <Shadow>[
                              Shadow(color: Colors.black54, blurRadius: 8),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Container(
                        height: 4,
                        width: 48,
                        decoration: BoxDecoration(
                          color: theme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroPosterPlaceholder extends StatelessWidget {
  const _HeroPosterPlaceholder({
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
      <Color>[theme.primary, theme.accentMagenta],
      <Color>[theme.secondary, const Color(0xFF5B7CFA)],
      <Color>[const Color(0xFFFF5A6A), const Color(0xFF2A1845)],
      <Color>[const Color(0xFF67E8F9), const Color(0xFF312E81)],
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
        children: <Widget>[
          Positioned(
            right: -48,
            top: -56,
            child: Icon(
              Icons.blur_on,
              size: 220,
              color: Colors.white.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            left: 32,
            top: 32,
            child: Text(
              symbol,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.22),
                fontSize: 96,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
