import 'package:flutter/material.dart';

import '../../../core/branding/app_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.message});

  final String? message;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<double> _textFade;
  late final Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    _logoFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );
    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.95, curve: Curves.easeOut),
    );
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.95, curve: Curves.easeOutCubic),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0A0A0A) : const Color(0xFFFAFAFA);
    final titleColor = isDark ? Colors.white : const Color(0xFF111111);
    final subtitleColor = isDark ? const Color(0xFFB0B0B0) : const Color(0xFF5A5A5A);
    final messageColor = isDark ? const Color(0xFF8A8A8A) : const Color(0xFF707070);
    final spinnerColor =
        isDark ? const Color(0xFFE9C46A) : Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          Positioned.fill(child: _BackgroundAura(isDark: isDark)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FadeTransition(
                  opacity: _logoFade,
                  child: ScaleTransition(
                    scale: _logoScale,
                    child: const AppLogo(size: 132),
                  ),
                ),
                const SizedBox(height: 36),
                SlideTransition(
                  position: _textSlide,
                  child: FadeTransition(
                    opacity: _textFade,
                    child: Column(
                      children: [
                        Text(
                          'Black Muasebe',
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Dükkan ciro takibi',
                          style: TextStyle(
                            color: subtitleColor,
                            fontSize: 14,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 72,
            child: Center(
              child: FadeTransition(
                opacity: _textFade,
                child: Column(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
                      ),
                    ),
                    if (widget.message != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        widget.message!,
                        style: TextStyle(
                          color: messageColor,
                          fontSize: 12,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackgroundAura extends StatelessWidget {
  const _BackgroundAura({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final gradient = isDark
        ? const RadialGradient(
            colors: [Color(0xFF1A1A1A), Color(0xFF0A0A0A)],
            radius: 1.1,
          )
        : const RadialGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFEDEDED)],
            radius: 1.1,
          );
    final auraColor = isDark
        ? const Color(0xFFD4A017).withValues(alpha: 0.18)
        : Theme.of(context).colorScheme.primary.withValues(alpha: 0.12);
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [auraColor, Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
