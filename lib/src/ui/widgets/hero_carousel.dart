import 'dart:async';
import 'package:flutter/material.dart';

import '../testing/ui_element_ids.dart';
import '../theme/elaina_theme.dart';

/// Home-page hero carousel for recent Bangumi attention items.
///
/// The widget owns only presentation and image lifecycle. Ranking windows,
/// provider caching, and Bangumi fallback decisions stay in the home/domain
/// composition that creates [HeroCarouselItem]s.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({
    super.key,
    this.autoScroll = true,
    this.items = const <HeroCarouselItem>[],
    this.onOpenDetail,
  });

  final bool autoScroll;
  final List<HeroCarouselItem> items;
  final ValueChanged<String>? onOpenDetail;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

final class HeroCarouselItem {
  const HeroCarouselItem({
    required this.title,
    required this.symbol,
    this.subjectId,
    this.coverUri,
    this.popularitySentence,
  });

  final String title;
  final String symbol;
  final String? subjectId;
  final Uri? coverUri;
  final String? popularitySentence;
}

class _HeroCarouselState extends State<HeroCarousel> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  static const double _carouselHeight = 400.0;
  static const double _itemWidth = 500.0;
  static const double _itemGap = 24.0;
  static const double _cachePinSize = 1.0;
  static const Duration _autoScrollInterval = Duration(seconds: 4);
  static const Duration _scrollAnimationDuration = Duration(milliseconds: 800);
  final Map<String, ImageProvider<Object>> _imageProvidersByUri =
      <String, ImageProvider<Object>>{};
  final Set<String> _precachedImageUris = <String>{};

  static const List<HeroCarouselItem> _fallbackItems = <HeroCarouselItem>[
    HeroCarouselItem(title: 'Stellar Echoes', symbol: 'SE'),
    HeroCarouselItem(title: 'Neon Protocol', symbol: 'NP'),
    HeroCarouselItem(title: 'Crimson Horizon', symbol: 'CH'),
    HeroCarouselItem(title: 'Prismatic Resonance', symbol: 'PR'),
  ];

  @override
  void initState() {
    super.initState();
    _syncImageProviders();
    if (widget.autoScroll) {
      _startAutoScroll();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheHeroImages();
  }

  @override
  void didUpdateWidget(HeroCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncImageProviders();
    _precacheHeroImages();
    if (oldWidget.autoScroll != widget.autoScroll) {
      _timer?.cancel();
      _timer = null;
      if (widget.autoScroll) {
        _startAutoScroll();
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(_autoScrollInterval, (timer) {
      if (!mounted || !TickerMode.valuesOf(context).enabled) return;
      if (!_scrollController.hasClients) return;

      final currentOffset = _scrollController.offset;
      final advanceAmount = _itemWidth + _itemGap;

      _scrollController.animateTo(
        currentOffset + advanceAmount,
        duration: _scrollAnimationDuration,
        curve: Curves.easeInOut,
      );
    });
  }

  void _syncImageProviders() {
    final Map<String, ImageProvider<Object>> next =
        <String, ImageProvider<Object>>{};
    for (final HeroCarouselItem item in _effectiveItems()) {
      final Uri? coverUri = item.coverUri;
      if (coverUri == null) continue;
      final String key = coverUri.toString();
      next[key] = _imageProvidersByUri[key] ?? NetworkImage(key);
    }
    _imageProvidersByUri
      ..clear()
      ..addAll(next);
  }

  void _precacheHeroImages() {
    for (final MapEntry<String, ImageProvider<Object>> entry
        in _imageProvidersByUri.entries) {
      if (!_precachedImageUris.add(entry.key)) continue;
      unawaited(
        precacheImage(
          entry.value,
          context,
          onError: (Object error, StackTrace? stackTrace) {
            return;
          },
        ),
      );
    }
  }

  List<HeroCarouselItem> _effectiveItems() {
    return widget.items.isEmpty ? _fallbackItems : widget.items;
  }

  ImageProvider<Object>? _imageProviderFor(Uri? uri) {
    if (uri == null) return null;
    return _imageProvidersByUri[uri.toString()];
  }

  @override
  Widget build(BuildContext context) {
    final theme = ElainaTheme.of(context);
    final List<HeroCarouselItem> items = _effectiveItems();

    return SizedBox(
      height: _carouselHeight,
      child: Stack(
        children: <Widget>[
          ListView.builder(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (BuildContext context, int index) {
              final int itemIndex = index % items.length;
              final HeroCarouselItem item = items[itemIndex];
              return Padding(
                padding: const EdgeInsets.only(right: _itemGap),
                child: _HeroCarouselCard(
                  key: ValueKey<String>(
                    UiElementIds.heroCarouselItem(
                      item.subjectId ?? item.title,
                    ),
                  ),
                  item: item,
                  index: itemIndex,
                  width: _itemWidth,
                  theme: theme,
                  imageProvider: _imageProviderFor(item.coverUri),
                  onOpenDetail: widget.onOpenDetail,
                ),
              );
            },
          ),
          _HeroImageCachePin(
            providers: _imageProvidersByUri.values.toList(growable: false),
            size: _cachePinSize,
          ),
        ],
      ),
    );
  }
}

class _HeroCarouselCard extends StatelessWidget {
  const _HeroCarouselCard({
    super.key,
    required this.item,
    required this.index,
    required this.width,
    required this.theme,
    required this.imageProvider,
    required this.onOpenDetail,
  });

  final HeroCarouselItem item;
  final int index;
  final double width;
  final ElainaThemeData theme;
  final ImageProvider<Object>? imageProvider;
  final ValueChanged<String>? onOpenDetail;
  static const double _overlayInset = 24.0;
  static const double _metadataGap = 10.0;
  static const double _titleFontSize = 32.0;
  static const double _popularityFontSize = 13.0;
  static const double _accentLineWidth = 48.0;
  static const double _accentLineHeight = 4.0;
  static const double _accentLineRadius = 2.0;
  static const double _overlayGradientStart = 0.48;
  static const double _overlayGradientEnd = 1.0;
  static const double _overlayOpacity = 0.78;

  @override
  Widget build(BuildContext context) {
    final String? subjectId = item.subjectId;
    final bool canOpenDetail = subjectId != null && onOpenDetail != null;
    final String itemId = subjectId ?? item.title;
    return SizedBox(
      width: width,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16.0),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          mouseCursor: canOpenDetail
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onTap: canOpenDetail ? () => onOpenDetail!(subjectId) : null,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.0),
              color: theme.surface,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                RepaintBoundary(
                  child: KeyedSubtree(
                    key: ValueKey<String>(
                      UiElementIds.heroCarouselPoster(itemId),
                    ),
                    child: _HeroPosterPlaceholder(
                      index: index,
                      imageProvider: imageProvider,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        Colors.transparent,
                        Colors.black.withValues(alpha: _overlayOpacity),
                      ],
                      stops: const <double>[
                        _overlayGradientStart,
                        _overlayGradientEnd,
                      ],
                    ),
                  ),
                ),
                Positioned(
                  key: ValueKey<String>(UiElementIds.heroCarouselMeta(itemId)),
                  left: _overlayInset,
                  right: _overlayInset,
                  bottom: _overlayInset,
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(
                      color: Colors.white,
                      shadows: <Shadow>[
                        Shadow(color: Colors.black54, blurRadius: 10),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: _titleFontSize,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (item.popularitySentence != null) ...<Widget>[
                          const SizedBox(height: _metadataGap),
                          Text(
                            item.popularitySentence!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.78),
                              fontSize: _popularityFontSize,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: _metadataGap),
                        Container(
                          height: _accentLineHeight,
                          width: _accentLineWidth,
                          decoration: BoxDecoration(
                            color: theme.primary,
                            borderRadius:
                                BorderRadius.circular(_accentLineRadius),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPosterPlaceholder extends StatelessWidget {
  const _HeroPosterPlaceholder({
    required this.index,
    this.imageProvider,
  });

  final int index;
  final ImageProvider<Object>? imageProvider;

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
    final ImageProvider<Object>? provider = imageProvider;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        image: provider == null
            ? null
            : DecorationImage(
                image: provider,
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
        ],
      ),
    );
  }
}

class _HeroImageCachePin extends StatelessWidget {
  const _HeroImageCachePin({
    required this.providers,
    required this.size,
  });

  final List<ImageProvider<Object>> providers;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) return const SizedBox.shrink();
    // The ListView is logically infinite, so keep image providers pinned
    // outside the visible cards. Otherwise Flutter may evict the first images
    // during a loop and the second pass can degrade to text-only cards.
    return Positioned(
      left: 0,
      top: 0,
      width: size,
      height: size,
      child: ExcludeSemantics(
        child: IgnorePointer(
          child: Opacity(
            opacity: 0,
            child: Stack(
              key: const ValueKey<String>(UiElementIds.heroCarouselCachePin),
              children: <Widget>[
                for (final ImageProvider<Object> provider in providers)
                  Image(
                    image: provider,
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    errorBuilder: (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return const SizedBox.shrink();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
