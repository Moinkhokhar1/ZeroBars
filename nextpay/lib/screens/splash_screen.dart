import 'package:flutter/material.dart';
import 'onboarding_carousel_screen.dart';

// ── Design tokens (dark splash variant of the purple used across
//    login_screen.dart / register_screen.dart) ─────────────────────
const _splashBg = Color(0xFF0E0C16);
const _purple = Color(0xFF6C4CF1);
const _purpleGlow = Color(0xFF8B6BFF);

/// First screen a brand-new user sees. Shows the NextPay wordmark with a
/// soft purple glow, then hands off to [OnboardingCarouselScreen] once the
/// intro animation finishes.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      // IMPORTANT: push, never pushReplacement, here. This widget is
      // rendered inline by AppRoot (main.dart) as its *first* route — the
      // route AppRoot itself relies on staying put so it can pop back to
      // it (and react to auth state) once login/registration succeeds.
      // pushReplacement would remove that first route from the stack
      // entirely and silently break sign-in.
      Navigator.of(context).push(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, __, ___) => const OnboardingCarouselScreen(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _splashBg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              children: [
                const Spacer(flex: 3),
                _Wordmark(),
                const SizedBox(height: 18),
                const Text(
                  "Payments made simple,\nfor real life.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFB9B4CC),
                    fontSize: 15,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(flex: 4),
                const _FooterTags(),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Soft glow behind the wordmark.
        Container(
          width: 220,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _purpleGlow.withValues(alpha: 0.45),
                blurRadius: 80,
                spreadRadius: 10,
              ),
            ],
          ),
        ),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
            children: [
              TextSpan(text: "Next", style: TextStyle(color: Colors.white)),
              TextSpan(text: "Pay", style: TextStyle(color: _purpleGlow)),
            ],
          ),
        ),
        Positioned(
          top: 4,
          right: -6,
          child: Icon(Icons.auto_awesome_rounded,
              color: _purpleGlow.withValues(alpha: 0.9), size: 20),
        ),
      ],
    );
  }
}

class _FooterTags extends StatelessWidget {
  const _FooterTags();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: Color(0xFF8E89A3),
      fontSize: 13,
      fontWeight: FontWeight.w500,
    );
    const dot = Text(" •  ", style: style);
    return const Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Secure", style: style),
        dot,
        Text("Offline-ready", style: style),
        dot,
        Text("Instant", style: style),
      ],
    );
  }
}