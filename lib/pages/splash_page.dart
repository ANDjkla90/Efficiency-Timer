import 'package:flutter/material.dart';

import '../services/app_settings.dart';
import '../theme.dart';

/// 开屏动画页：品牌标识 → 产品定位 → 三个核心功能依次错落呈现。
/// 节奏：整体约 2.6 秒，动画自然衔接后由调用方切入主界面；可点击提前跳过。
class SplashPage extends StatefulWidget {
  final VoidCallback onFinish;
  const SplashPage({super.key, required this.onFinish});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _titleSlide;
  late final Animation<double> _sloganSlide;
  late final List<Animation<double>> _features;
  late final List<Animation<double>> _dots;

  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    // 品牌标识：轻弹放大 + 淡入
    _logoScale = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.00, 0.26, curve: Curves.easeOutBack),
    );
    _logoFade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.00, 0.20, curve: Curves.easeOut),
    );
    // 标题 → 定位：依次上浮淡入
    _titleSlide = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.18, 0.42, curve: Curves.easeOutCubic),
    );
    _sloganSlide = CurvedAnimation(
      parent: _c,
      curve: const Interval(0.34, 0.55, curve: Curves.easeOutCubic),
    );
    // 三个核心功能：错落入场，视觉层级清晰
    _features = List.generate(3, (i) {
      final start = 0.50 + i * 0.12;
      return CurvedAnimation(
        parent: _c,
        curve: Interval(start, start + 0.20, curve: Curves.easeOutCubic),
      );
    });
    // 底部进度点依次亮起
    _dots = List.generate(3, (i) {
      final start = 0.55 + i * 0.13;
      return CurvedAnimation(
        parent: _c,
        curve: Interval(start, start + 0.12, curve: Curves.easeOut),
      );
    });
    _c.addStatusListener((status) {
      if (status == AnimationStatus.completed) _finish();
    });
    _c.forward();
  }

  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinish();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.stringsOf(context);
    final primary = Tones.primary(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    // 响应式：品牌区尺寸随屏幕短边缩放，小屏不拥挤、大屏不过散
    final scale = (size.shortestSide / 400).clamp(0.8, 1.35);
    final logoSize = 108.0 * scale;
    final titleSize = 40.0 * scale;

    return Scaffold(
      body: GestureDetector(
        onTap: _finish,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          Color.lerp(primary, Colors.black, 0.86)!,
                          const Color(0xFF0E0F12),
                        ]
                      : [
                          Color.lerp(primary, Colors.white, 0.90)!,
                          Colors.white,
                        ],
                ),
              ),
              child: SafeArea(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 主内容：品牌 + 定位 + 三功能
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 2),
                        // 品牌标识
                        FadeTransition(
                          opacity: _logoFade,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: Container(
                              width: logoSize,
                              height: logoSize,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: heroGradient(context),
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: primary.withValues(alpha: 0.35),
                                    blurRadius: 28 * scale,
                                    offset: Offset(0, 10 * scale),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.access_time_filled,
                                color: Colors.white,
                                size: 54 * scale,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 26 * scale),
                        // 应用名
                        _slideUp(
                          _titleSlide,
                          Text(
                            s.appTitle,
                            style: TextStyle(
                              fontSize: titleSize,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // 产品定位
                        _slideUp(
                          _sloganSlide,
                          Text(
                            s.splashDesc,
                            style: TextStyle(
                              fontSize: 15 * scale,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                        SizedBox(height: 8),
                        _slideUp(
                          _sloganSlide,
                          Text(
                            s.splashSlogan,
                            style: TextStyle(
                              fontSize: 13 * scale,
                              fontWeight: FontWeight.w600,
                              color: primary,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const Spacer(flex: 1),
                        // 三个核心功能：图标 + 文字卡片，依次错落入场
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 28 * scale),
                          child: Row(
                            children: List.generate(3, (i) {
                              return Expanded(
                                child: _featureCard(
                                  index: i,
                                  icon: [
                                    Icons.edit_calendar_outlined,
                                    Icons.calculate_outlined,
                                    Icons.receipt_long_outlined,
                                  ][i],
                                  label: s.splashFeatures[i],
                                  anim: _features[i],
                                  primary: primary,
                                  scale: scale,
                                  isDark: isDark,
                                ),
                              );
                            }),
                          ),
                        ),
                        const Spacer(flex: 2),
                      ],
                    ),
                    // 底部：进度指示 + 跳过
                    Positioned(
                      bottom: 24,
                      left: 0,
                      right: 0,
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (i) {
                              final v = _dots[i].value;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 80),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: 6 + 10 * v,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: primary.withValues(
                                      alpha: 0.35 + 0.65 * v),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            s.splashSkip,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _slideUp(Animation<double> anim, Widget child) {
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  Widget _featureCard({
    required int index,
    required IconData icon,
    required String label,
    required Animation<double> anim,
    required Color primary,
    required double scale,
    required bool isDark,
  }) {
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.4),
          end: Offset.zero,
        ).animate(anim),
        child: Column(
          children: [
            Container(
              width: 52 * scale,
              height: 52 * scale,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: isDark ? 0.18 : 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: primary, size: 26 * scale),
            ),
            SizedBox(height: 10 * scale),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5 * scale,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
