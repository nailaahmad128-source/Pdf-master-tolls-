import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/storage/app_data_controller.dart';
import '../../../core/widgets/banner_ad_slot.dart';
import '../../library/screens/library_screen.dart';
import '../../tools/screens/tools_screen.dart';
import '../../tools/screens/tool_router.dart';
import '../../qr/screens/qr_scan_screen.dart';
import '../../qr/screens/qr_generate_screen.dart';
import '../widgets/hero_header.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/popular_tool_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppDataController>();
    final docCount = data.documents.length;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: HeroHeader(docCount: docCount)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quick actions', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 104,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          QuickActionCard(
                            icon: Icons.merge_type_rounded,
                            label: 'Merge',
                            color: AppColors.toolMerge,
                            onTap: () => openTool(context, ToolId.merge),
                          ),
                          QuickActionCard(
                            icon: Icons.compress_rounded,
                            label: 'Compress',
                            color: AppColors.toolCompress,
                            onTap: () => openTool(context, ToolId.compress),
                          ),
                          QuickActionCard(
                            icon: Icons.draw_rounded,
                            label: 'Fill & Sign',
                            color: AppColors.toolSign,
                            onTap: () => openTool(context, ToolId.fillSign),
                          ),
                          QuickActionCard(
                            icon: Icons.qr_code_scanner_rounded,
                            label: 'Scan QR',
                            color: AppColors.toolQrScan,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const QrScanScreen())),
                          ),
                          QuickActionCard(
                            icon: Icons.qr_code_2_rounded,
                            label: 'Create QR',
                            color: AppColors.toolQrGen,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const QrGenerateScreen())),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Popular tools', style: Theme.of(context).textTheme.titleLarge),
                        TextButton(
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const ToolsScreen())),
                          child: const Text('See all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: ToolsCatalog.popularOnHome.map((id) {
                        final tool = ToolsCatalog.byId(id);
                        return PopularToolCard(
                          tool: tool,
                          onTap: () => openTool(context, tool.id),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
                    _LibraryShortcut(docCount: docCount),
                    const SizedBox(height: 20),
                    const Center(child: BannerAdSlot()),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryShortcut extends StatelessWidget {
  final int docCount;
  const _LibraryShortcut({required this.docCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(
            context, MaterialPageRoute(builder: (_) => const LibraryScreen())),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.folder_rounded, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Library', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      docCount == 0 ? 'No files yet' : '$docCount file${docCount == 1 ? '' : 's'} saved',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
