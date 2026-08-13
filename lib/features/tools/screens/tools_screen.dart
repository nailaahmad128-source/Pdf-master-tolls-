import 'package:flutter/material.dart';
import '../../../core/constants/tools_catalog.dart';
import '../../../core/widgets/banner_ad_slot.dart';
import 'tool_router.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tools')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.98,
                ),
                itemCount: ToolsCatalog.all.length,
                itemBuilder: (ctx, i) {
                  final tool = ToolsCatalog.all[i];
                  return _ToolGridCard(tool: tool, onTap: () => openTool(context, tool.id));
                },
              ),
            ),
            const BannerAdSlot(),
          ],
        ),
      ),
    );
  }
}

class _ToolGridCard extends StatelessWidget {
  final ToolDef tool;
  final VoidCallback onTap;
  const _ToolGridCard({required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tool.color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(tool.icon, color: tool.color, size: 24),
              ),
              const Spacer(),
              Text(tool.title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                tool.subtitle,
                style: theme.textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
