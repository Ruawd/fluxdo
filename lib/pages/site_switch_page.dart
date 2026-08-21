import 'package:app_icons/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:m3e_ui/m3e_ui.dart';

import '../config/discourse_site.dart';
import '../l10n/s.dart';
import '../services/active_site_service.dart';
import '../services/site_switch_coordinator.dart';
import '../services/toast_service.dart';
import '../utils/dialog_utils.dart';

class SiteSwitchPage extends StatefulWidget {
  const SiteSwitchPage({super.key});

  @override
  State<SiteSwitchPage> createState() => _SiteSwitchPageState();
}

class _SiteSwitchPageState extends State<SiteSwitchPage> {
  bool _switching = false;

  Future<void> _select(DiscourseSite site) async {
    final current = ActiveSiteService.instance.current;
    if (_switching || current.id == site.id) return;

    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.siteSwitch_confirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${current.displayName}  →  ${site.displayName}'),
            const SizedBox(height: 12),
            Text(context.l10n.siteSwitch_confirmMessage),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.siteSwitch_action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _switching = true);
    final result = await SiteSwitchCoordinator.instance.switchTo(site);
    if (!mounted) return;
    setState(() => _switching = false);

    switch (result) {
      case SiteSwitchResult.switched:
      case SiteSwitchResult.unchanged:
        break;
      case SiteSwitchResult.verificationInProgress:
        ToastService.showInfo(context.l10n.siteSwitch_verificationInProgress);
        break;
      case SiteSwitchResult.failed:
        ToastService.showError(context.l10n.siteSwitch_failed);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final current = ActiveSiteService.instance.current;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.siteSwitch_title)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        color: theme.colorScheme.primaryContainer.withValues(
                          alpha: 0.55,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Symbols.swap_horiz_rounded,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      context.l10n.siteSwitch_description,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      context.l10n.siteSwitch_accountKept,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.siteSwitch_current,
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final site in DiscourseSiteRegistry.all) ...[
                        _SiteCard(
                          site: site,
                          selected: site.id == current.id,
                          enabled: !_switching,
                          onTap: () => _select(site),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_switching) ...[
            const Positioned.fill(
              child: ModalBarrier(dismissible: false, color: Color(0x55000000)),
            ),
            Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const LoadingSpinner(size: 24),
                      const SizedBox(width: 14),
                      Text(context.l10n.siteSwitch_switching),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.site,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final DiscourseSite site;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLinuxDo = site.id == DiscourseSiteRegistry.linuxDoId;
    final accent = isLinuxDo
        ? const Color(0xFF1F8BFF)
        : const Color(0xFFE75B35);

    return Card(
      clipBehavior: Clip.antiAlias,
      color: selected ? scheme.secondaryContainer : scheme.surfaceContainerLow,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isLinuxDo ? Symbols.terminal_rounded : Symbols.dns_rounded,
                  color: accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      site.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      site.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      site.baseUrl,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                selected
                    ? Symbols.check_circle_rounded
                    : Symbols.chevron_right_rounded,
                fill: selected ? 1 : 0,
                color: selected ? scheme.primary : scheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
