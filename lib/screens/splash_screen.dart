import 'package:flutter/material.dart';
import '../core/storage/local_store.dart';
import '../theme/app_text_styles.dart';
import '../widgets/root_shell.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _scale = Tween<double>(begin: 0.7, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _fade = CurvedAnimation(parent: _controller, curve: const Interval(0, 0.6, curve: Curves.easeOut));
    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      final seenOnboarding = LocalStore.instance.getBool(StoreKeys.onboardingComplete);
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, a, __) => FadeTransition(
            opacity: a,
            child: seenOnboarding ? const RootShell() : const OnboardingScreen(),
          ),
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF3730A3), Color(0xFF4F46E5), Color(0xFF6D5BF5)],
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Ambient soft glow shapes
            Positioned(
              top: -60,
              right: -40,
              child: _glowCircle(220, Colors.white.withOpacity(0.08)),
            ),
            Positioned(
              bottom: -80,
              left: -60,
              child: _glowCircle(260, const Color(0xFFFF6B4A).withOpacity(0.18)),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: _scale,
                  child: FadeTransition(
                    opacity: _fade,
                    child: Container(
                      width: 104,
                      height: 104,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 30,
                            offset: const Offset(0, 14),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.picture_as_pdf_rounded, size: 52, color: Color(0xFF4F46E5)),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                FadeTransition(
                  opacity: _fade,
                  child: Text('PDF Master Tools', style: AppTextStyles.headline(Colors.white)),
                ),
                const SizedBox(height: 8),
                FadeTransition(
                  opacity: _fade,
                  child: Text(
                    'Scan · Edit · Convert · Sign',
                    style: AppTextStyles.bodyMedium(Colors.white.withOpacity(0.8)),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 48,
              child: FadeTransition(
                opacity: _fade,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(Colors.white.withOpacity(0.85)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _glowCircle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
}
