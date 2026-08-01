import 'package:flutter/material.dart';

import '../models/tool_item.dart';
import '../theme/app_text_styles.dart';
import '../widgets/state_views.dart';
import '../widgets/tool_card.dart';
import '../widgets/tool_navigation.dart';

/// QR category landing screen. QR Scanner and QR Generator are
/// completely independent tools — each opens its own screen with its
/// own controls and its own history; nothing is shared between them.
class QrToolsScreen extends StatelessWidget {
  const QrToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tools = ToolCatalog.byCategory(ToolCategory.qr);
    return Scaffold(
      appBar: AppBar(title: Text('QR Tools', style: AppTextStyles.headline(theme.colorScheme.onSurface))),
      body: tools.isEmpty
          ? const EmptyStateView(
              icon: Icons.qr_code_rounded,
              title: 'No QR tools available',
              message: 'QR tools will appear here.',
            )
          : SafeArea(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                itemCount: tools.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.98,
                ),
                itemBuilder: (context, i) => ToolCard(item: tools[i], onTap: () => openTool(context, tools[i])),
              ),
            ),
    );
  }
}
