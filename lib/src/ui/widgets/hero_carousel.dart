import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/celesteria_theme.dart';

class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key});

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  final ScrollController _scrollController = ScrollController();
  Timer? _timer;
  // ignore: unused_field  // TODO(ui): wire carousel index to active page indicator
  int _currentIndex = 0;
  final double _itemWidth = 500.0;
  final double _itemGap = 24.0;
  
  final List<Map<String, String>> _items = const [
    {
      'title': 'Stellar Echoes',
      'image': 'https://lh3.googleusercontent.com/aida/AP1WRLuYUkwKue-cg5hlpVu5ozGiyPYLJIxf4Ni2fdIxQSZ42vNucwZD80pZHzf5B5iItUWiuatClpPzs3VezAMZ4tIekXoa-A3MpZJeHmGZJVDORzefSzNNQ2qIUXnLWlELcruNMXvXWH0Qei9E5TUOXk3KJuhHKkr5eFEL8lFAZMelgPuVsIJxKXiofDfzlf5y99EHxKaWOEUFL_pu0hxlNEa7B0rjsVHObz5sGHrhBW7bEy7XTpFWPsIeJg',
    },
    {
      'title': 'Neon Protocol',
      'image': 'https://lh3.googleusercontent.com/aida/AP1WRLu7xrcR7YrXANCg1uwgBTTDSo4RmoqOC5GdtHBtuX69kX2iKbwUbE5EPhBHy1Zhwjc6X-aTAOXwU0ZxFWkUL108Jfu6Gye5sXpueQCOPXDJV0Z9YFP52FCKSMmx4_22XBePIb1dspPaSGgDxK7gy-mdWleeKVOPuFeSLmWUubLbvyU-of38Gcwf4L8XXQTY3ofG-KKS4B02lzqdegxoTAQhQxdj9USSAQF3rpAmNnOzLiipDrSL2eVYhCg',
    },
    {
      'title': 'Crimson Horizon',
      'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuD8CzTs8kOiGnlNeawZZVPOuY2Mr50UQoZTcvvTHbbi24S1aeMMSLsuCPRQRIDtYtpDCk5CVDEkl9_yGa19gk4v-YeoU4msFvHwiIBU-YARuwojSaIo9pqkJz9z6ALapTec5caDkaZLDQZ8DSqJwGl5tRLrbTwBwGR-PLC3L-qq4T2F6CBsoJ7HrGmMj9coNVkUi-klQ1sjopmv4VejXJ-SrWUfU4q_Hn7D3bbsMa-LCTgC7gQl7E6s1QIznUA4dhuOYc6dD11Eopc',
    },
    {
      'title': 'Prismatic Resonance',
      'image': 'https://lh3.googleusercontent.com/aida-public/AB6AXuB-yPS96O588Z7pbu3bx6kFScZOE5xyeSkkqvbhTiJhQBGLU3yw59QwqG_PeNE34X5I1PoTklkOdNifafJuGYvr1gK605k0Bc_u8oqceUlQMn6qIyqRWp9nu-fj3yM3IZcANxmEWTH1ZHdEF62xq2PaW0_A2lrvytVE-BloAlQYOqiKjZ5kQr443RV5q162cebkoGaH8NX852lXG_LwuKtDE1s1MPAcurndQsJWZEE-yyIIFn0HIoFxeKTL-ff7m37FyFoNZUMjE6o',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
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
        _currentIndex = 0;
      } else {
        _currentIndex++;
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
    final theme = CelesteriaTheme.of(context);
    
    return SizedBox(
      height: 400,
      child: ListView.separated(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _items.length,
        separatorBuilder: (context, index) => SizedBox(width: _itemGap),
        itemBuilder: (context, index) {
          final item = _items[index];
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
                Image.network(
                  item['image']!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(color: theme.surface),
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
                        item['title']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          shadows: [Shadow(color: Colors.black54, blurRadius: 10)],
                        ),
                      ),
                      const SizedBox(height: 8),
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
