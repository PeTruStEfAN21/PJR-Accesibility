import 'package:flutter/material.dart';

import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/echo_style.dart';
import '../../widgets/pressable.dart';
import 'sounds_screen.dart';

/// The top-bar switch for "Visible sound". The state shows in the icon and the
/// fill (outlined when off or paused, filled when on), never in colour alone.
class SoundsPill extends StatelessWidget {
  const SoundsPill({super.key});

  /// Above this text scale only the icon stays, so the label is not cut in the bar.
  static const _iconOnlyFrom = 1.3;

  @override
  Widget build(BuildContext context) {
    final services = ServicesScope.of(context);
    final listening = services.soundListening;
    return ListenableBuilder(
      listenable: listening,
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final palette = EchoPalette.of(context);
        final theme = Theme.of(context);
        final on = listening.wanted && !listening.paused;
        final foreground = on ? palette.onPrimary : palette.text;
        final iconOnly = MediaQuery.textScalerOf(context).scale(1) > _iconOnlyFrom;

        void tap() {
          // Where recognition cannot run, the Sounds screen explains why and offers the test buttons.
          if (!services.sounds.isAvailable) {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SoundsScreen()));
          } else if (listening.wanted) {
            listening.disable();
          } else {
            listening.enable();
          }
        }

        return Semantics(
          button: true,
          toggled: listening.wanted,
          label: listening.paused
              ? l10n.soundsPillPaused
              : listening.wanted
                  ? l10n.soundsPillOn
                  : l10n.soundsPillOff,
          excludeSemantics: true,
          child: Pressable(
            child: Material(
              color: on ? palette.primary : Colors.transparent,
              shape: StadiumBorder(side: on ? BorderSide.none : BorderSide(color: palette.control, width: 1.5)),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: tap,
                splashFactory: NoSplash.splashFactory,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: iconOnly ? 12 : 16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          listening.paused
                              ? Icons.pause_circle_outline
                              : on
                                  ? Icons.hearing
                                  : Icons.hearing_disabled,
                          size: 20,
                          color: on ? foreground : palette.brand,
                        ),
                        if (!iconOnly) ...[
                          const SizedBox(width: 8),
                          Text(
                            l10n.soundsPill,
                            style: theme.textTheme.labelLarge?.copyWith(color: foreground, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
