import 'package:flutter/material.dart';

import '../core/session_connection.dart';
import '../l10n/app_localizations.dart';

/// Connection state in words and icon, never by colour alone.
class ConnectionBanner extends StatelessWidget {
  const ConnectionBanner({super.key, required this.status, this.detail});

  final ConnectionStatus status;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (icon, text, background, foreground) = switch (status) {
      ConnectionStatus.connecting => (Icons.sync, l10n.connConnecting, scheme.secondaryContainer, scheme.onSecondaryContainer),
      ConnectionStatus.connected => (Icons.check_circle, l10n.connConnected, scheme.primaryContainer, scheme.onPrimaryContainer),
      ConnectionStatus.reconnecting => (Icons.wifi_off, l10n.connReconnecting, scheme.errorContainer, scheme.onErrorContainer),
      ConnectionStatus.closed => (Icons.block, l10n.connClosed, scheme.errorContainer, scheme.onErrorContainer),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: background,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: foreground, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                detail == null ? text : '$text · $detail',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
