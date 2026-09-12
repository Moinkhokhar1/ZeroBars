import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';

// ── Design tokens (matches login_screen.dart / register_screen.dart) ──
const _bg = Color(0xFFF7F6F2);
const _surface = Colors.white;
const _textPrimary = Color(0xFF1A1A1A);
const _textSecondary = Color(0xFF6B6B68);
const _border = Color(0xFFE9E7E1);

const _purple = Color(0xFF534AB7);
const _purpleDark = Color(0xFF26215C);
const _accent = Color(0xFF4A2FCC);

const _onboardingSeenKey = 'has_seen_onboarding';

Future<void> _markOnboardingSeen() =>
    StorageService.setItem(_onboardingSeenKey, '1');

/// Three swipeable intro slides (Skip + dots + next-arrow), followed by a
/// final "Get Started / Sign In" screen once the user reaches the end.
class OnboardingCarouselScreen extends StatefulWidget {
  const OnboardingCarouselScreen({super.key});

  @override
  State<OnboardingCarouselScreen> createState() =>
      _OnboardingCarouselScreenState();
}

class _OnboardingCarouselScreenState extends State<OnboardingCarouselScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    _SlideData(
      title: "Send Money\nin a Snap",
      subtitle: "Instant, secure and effortless\npayments to anyone.",
      illustration: _SendMoneyIllustration(),
    ),
    _SlideData(
      title: "Pay, Split, Share",
      subtitle: "Split bills, collect funds and\nmanage expenses with friends.",
      illustration: _SplitShareIllustration(),
    ),
    _SlideData(
      title: "Works Even\nWithout Internet",
      subtitle: "Bank-grade security keeps every\noffline payment protected.",
      illustration: _OfflineSafeIllustration(),
    ),
  ];

  void _goToFinal() {
    _markOnboardingSeen();
    // push (not pushReplacement) — keeps AppRoot's route at the bottom of
    // the stack so it can be popped back to on successful login/register.
    // See the note in splash_screen.dart for why this matters.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const _OnboardingFinalScreen()),
    );
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _goToFinal();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) => _SlideView(data: _slides[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _goToFinal,
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        "Skip",
                        style: TextStyle(
                          color: _textSecondary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: List.generate(
                      _slides.length,
                          (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _page ? 20 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _page ? _accent : _border,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: _next,
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: _accent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideData {
  final String title;
  final String subtitle;
  final Widget illustration;
  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.illustration,
  });
}

class _SlideView extends StatelessWidget {
  final _SlideData data;
  const _SlideView({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Expanded(child: Center(child: data.illustration)),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: _textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── Illustration 1: Send Money in a Snap ───────────────────────────
class _SendMoneyIllustration extends StatelessWidget {
  const _SendMoneyIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 10,
            top: 30,
            child: Transform.rotate(
              angle: -0.18,
              child: Container(
                width: 130,
                height: 150,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_purple, _accent],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.send_rounded,
                    color: Colors.white, size: 46),
              ),
            ),
          ),
          Positioned(
            right: 6,
            bottom: 24,
            child: Transform.rotate(
              angle: 0.14,
              child: Container(
                width: 96,
                height: 110,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: _border),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 18,
                        offset: Offset(0, 10)),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.sentiment_satisfied_alt_rounded,
                    color: _accent, size: 40),
              ),
            ),
          ),
          const Positioned(
            top: 0,
            right: 30,
            child: Icon(Icons.bolt_rounded, color: _accent, size: 22),
          ),
          const Positioned(
            top: 14,
            right: 50,
            child: Icon(Icons.bolt_rounded, color: _accent, size: 16),
          ),
        ],
      ),
    );
  }
}

// ── Illustration 2: Pay, Split, Share ───────────────────────────────
class _SplitShareIllustration extends StatelessWidget {
  const _SplitShareIllustration();

  static const _avatars = [
    (Color(0xFFD6E4FF), Icons.face_rounded, Alignment(-0.75, -0.75)),
    (Color(0xFFFFDDE1), Icons.tag_faces_rounded, Alignment(0.75, -0.75)),
    (Color(0xFFF3DDFF), Icons.sentiment_satisfied_alt_rounded,
    Alignment(-0.75, 0.75)),
    (Color(0xFFD4F5E5), Icons.account_circle_rounded, Alignment(0.75, 0.75)),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (final (color, icon, alignment) in _avatars)
            Align(
              alignment: alignment,
              child: Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: _surface, width: 3),
                  boxShadow: const [
                    BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 10,
                        offset: Offset(0, 6)),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 34, color: _purpleDark),
              ),
            ),
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_purple, _accent],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: _bg, width: 4),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.groups_rounded,
                color: Colors.white, size: 38),
          ),
        ],
      ),
    );
  }
}

// ── Illustration 3: Works Even Without Internet ─────────────────────
class _OfflineSafeIllustration extends StatelessWidget {
  const _OfflineSafeIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 110,
            height: 170,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: _purple, width: 2.5),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 20,
                    offset: Offset(0, 12)),
              ],
            ),
            alignment: Alignment.center,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: _accent,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bolt_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
          Positioned(
            left: 0,
            top: 18,
            child: _Chip(
              icon: Icons.lock_rounded,
              iconColor: const Color(0xFF16A34A),
              iconBg: const Color(0xFFDCFCE7),
              label: "Secure",
            ),
          ),
          Positioned(
            right: 0,
            top: 66,
            child: _Chip(
              icon: Icons.verified_rounded,
              iconColor: _accent,
              iconBg: const Color(0xFFEDE9FF),
              label: "Reliable",
            ),
          ),
          Positioned(
            left: 6,
            bottom: 10,
            child: _Chip(
              icon: Icons.wifi_off_rounded,
              iconColor: const Color(0xFF2563EB),
              iconBg: const Color(0xFFDBEAFE),
              label: "Always with you",
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  const _Chip({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Icon(icon, size: 13, color: iconColor),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Final screen: "Ready to simplify your payments?" ───────────────
class _OnboardingFinalScreen extends StatelessWidget {
  const _OnboardingFinalScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
          child: Column(
            children: [
              const Spacer(flex: 3),
              Container(
                width: 88,
                height: 88,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: _accent.withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/icon/app_icon.png',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 180,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _accent.withValues(alpha: 0.25),
                          blurRadius: 60,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  RichText(
                    text: const TextSpan(
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                      children: [
                        TextSpan(
                            text: "Next", style: TextStyle(color: _purpleDark)),
                        TextSpan(text: "Pay", style: TextStyle(color: _accent)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const Text(
                "Ready to simplify\nyour payments?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                  height: 1.3,
                ),
              ),
              const Spacer(flex: 4),
              _PrimaryButton(
                label: "Get Started",
                onTap: () {
                  // push, not pushReplacement — see splash_screen.dart.
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RegisterScreen()),
                  );
                },
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? ",
                      style: TextStyle(fontSize: 14, color: _textSecondary)),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    child: const Text(
                      "Sign In",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _accent,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _accent.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}