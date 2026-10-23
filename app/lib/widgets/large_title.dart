import 'package:flutter/material.dart';

import '../theme/echo_style.dart';

bool _pushed(BuildContext context) => ModalRoute.of(context)?.canPop ?? false;

/// The title of a main screen, as on iOS: large and bold, part of the page so it scrolls away with it.
/// It grows with the text size up to 150%, so it stays the biggest text without filling the screen.
/// On a pushed screen the title sits in the top bar instead ([backBarIfPushed]) and this shows nothing.
class LargeTitle extends StatelessWidget {
  const LargeTitle(this.text, {super.key, this.trailing});

  final String text;

  /// Beside the title, at its end (the mascot on Vibrații).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (_pushed(context)) return const SizedBox.shrink();
    final palette = EchoPalette.of(context);
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.5,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 8, 4, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 34,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: palette.text,
                  ),
                ),
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

/// A top bar for a main screen only when it was pushed (on a laptop, or from Dashboard): the back button
/// and the title, small and centred. In the phone's tabs there is none: the page shows a [LargeTitle].
PreferredSizeWidget? backBarIfPushed(BuildContext context, String title) =>
    _pushed(context) ? AppBar(backgroundColor: Colors.transparent, title: Text(title)) : null;
