import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'phone_shell.dart';

/// Where the app starts: the phone app with its floating bar on a phone-sized screen (the native app,
/// or a browser up to [HomeScreen.phoneMaxWidth]), the presenter's home on a laptop.
class EchoHome extends StatelessWidget {
  const EchoHome({super.key, this.web = kIsWeb});

  final bool web;

  @override
  Widget build(BuildContext context) {
    final laptop = web && MediaQuery.sizeOf(context).width > HomeScreen.phoneMaxWidth;
    return laptop ? const HomeScreen(presenterFirst: true) : const PhoneShell();
  }
}
