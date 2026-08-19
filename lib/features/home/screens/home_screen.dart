import 'package:flutter/material.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/banner_ad_slot.dart';
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
    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(child: HeroHeader(docCount: 0)),
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
                    Text(
                      'All Tools',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.5,
                      children: ToolsCatalog.all.map((tool) {
                        return PopularToolCard(
                          tool: tool,
                          onTap: () => openTool(context, tool.id),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),
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
