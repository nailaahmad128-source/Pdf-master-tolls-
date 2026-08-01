import 'package:flutter/material.dart';
import '../models/tool_item.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../theme/category_colors.dart';
import '../widgets/ad_banner.dart';
import '../widgets/list_tiles.dart';
import '../widgets/tool_card.dart';
import '../widgets/tool_navigation.dart';
import 'converter_screen.dart';
import 'pdf_tools_screen.dart';
import 'qr_tools_screen.dart';
import 'scanner_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openCategory(BuildContext context, ToolCategory category) {
    Widget screen = switch (category) {
      ToolCategory.pdf => const PdfToolsScreen(),
      ToolCategory.scan => const ScannerScreen(),
      ToolCategory.qr => const QrToolsScreen(),
      ToolCategory.convert => const ConverterScreen(),
    };
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final grid = ToolCatalog.all.take(8).toList();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              sliver: SliverToBoxAdapter(child: const _WelcomeBanner()),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(title: 'Categories', actionLabel: null, onActionTap: null),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: SizedBox(
                  height: 118,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: ToolCategory.values.where((e) => e != ToolCategory.scan).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => _CategoryChip(
                      category: ToolCategory.values.where((e) => e != ToolCategory.scan).toList()[i],
                      onTap: () => _openCategory(context, ToolCategory.values.where((e) => e != ToolCategory.scan).toList()[i]),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'All Tools',
                  actionLabel: 'See all',
                  onActionTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfToolsScreen())),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.98,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) => ToolCard(item: grid[i], onTap: () => openTool(context, grid[i])),
                  childCount: grid.length,
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: AdBannerWidget(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF6D5BF5)],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.brandIndigo.withOpacity(0.35), blurRadius: 22, offset: const Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('All PDF Tools in One Place', style: AppTextStyles.title(Colors.white)),
                const SizedBox(height: 6),
                Text(
                  'Merge • Split • Compress • Convert',
                  style: AppTextStyles.bodySmall(Colors.white.withOpacity(0.85)),
                ),
              ],
            ),
          ),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.document_scanner_rounded, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }
}

/// Horizontally scrollable category pill linking to a tool family.
class _CategoryChip extends StatelessWidget {
  final ToolCategory category;
  final VoidCallback? onTap;
  const _CategoryChip({required this.category, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = categoryPalette(category);
    final count = ToolCatalog.byCategory(category).length;
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: palette.primary.withOpacity(0.12),
        child: Container(
          width: 128,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: AppColors.cardShadow(theme.brightness, tint: palette.primary),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(color: palette.soft, borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.folder_rounded, color: palette.primary, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                categoryLabel(category),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.label(theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 2),
              Text('$count tools', style: AppTextStyles.caption(theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
