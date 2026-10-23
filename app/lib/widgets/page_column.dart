import 'package:flutter/widgets.dart';

/// A page's content in one centred column on a wide screen (desktop), the full width on a phone.
/// The same width as the other desktop forms (joining, Urgență), so lists and fields stay readable.
class PageColumn extends StatelessWidget {
  const PageColumn({super.key, required this.child, this.maxWidth = 560});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}
