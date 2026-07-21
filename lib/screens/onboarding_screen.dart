import 'package:flutter/material.dart';
import '../core/storage/local_store.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/app_buttons.dart';
import '../widgets/root_shell.dart';

class _OnboardPage {
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  const _OnboardPage(this.icon, this.color, this.title, this.description);
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _pages = [
    _OnboardPage(
      Icons.document_scanner_rounded,
      AppColors.scanPrimary,
      'Scan anything, instantly',
      'Turn photos of documents into crisp, perspective-corrected PDFs with auto edge detection.',
    ),
    _OnboardPage(
      Icons.merge_type_rounded,
      AppColors.pdfPrimary,
      'Edit PDFs like a pro',
      'Merge, split, compress, sign and lock your files — all in one clean, fast toolkit.',
    ),
    _OnboardPage(
      Icons.qr_code_2_rounded,
      AppColors.qrPrimary,
      'QR & conversions, covered',
      'Generate and scan QR codes, and convert units and currency without leaving the app.',
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
    } else {
      _finish();
    }
  }

  void _finish() {
    // Persist so the splash screen routes straight to RootShell on every
    // future launch instead of re-showing this intro flow.
    LocalStore.instance.setBool(StoreKeys.onboardingComplete, true);
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, a, __) => FadeTransition(opacity: a, child: const RootShell()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 20, top: 8),
                child: TextButton(
                  onPressed: _finish,
                  child: Text('Skip', style: AppTextStyles.button(theme.colorScheme.onSurfaceVariant)),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  final p = _pages[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Illustration placeholder — swap for real artwork/Lottie later.
                        Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            color: p.color.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(48),
                          ),
                          child: Icon(p.icon, size: 96, color: p.color),
                        ),
                        const SizedBox(height: 44),
                        Text(p.title, style: AppTextStyles.displayMedium(theme.colorScheme.onSurface), textAlign: TextAlign.center),
                        const SizedBox(height: 14),
                        Text(
                          p.description,
                          style: AppTextStyles.bodyLarge(theme.colorScheme.onSurfaceVariant),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: active ? 22 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active ? AppColors.brandIndigo : theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: PrimaryButton(
                label: isLast ? 'Get Started' : 'Next',
                icon: isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
