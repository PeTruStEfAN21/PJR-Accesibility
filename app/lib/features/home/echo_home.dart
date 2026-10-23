import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/account/account_service.dart';
import '../../core/services.dart';
import '../account/sign_in_screen.dart';
import 'home_screen.dart';
import 'phone_shell.dart';

/// Where the app starts: the phone app with its floating bar on a phone-sized screen (the native app,
/// or a browser up to [HomeScreen.phoneMaxWidth]), the presenter's home on a laptop.
/// With accounts on, the app opens on sign-in and goes in once the person is in, on the phone and on the
/// laptop (docs/specs/2026-10-23-login-cod-companie-design.md). The presenter still needs no
/// account: sign-in links straight to presenting (rule 6), and a QR link opens the captions before this.
class EchoHome extends StatelessWidget {
  const EchoHome({super.key, this.web = kIsWeb});

  final bool web;

  @override
  Widget build(BuildContext context) {
    final laptop = web && MediaQuery.sizeOf(context).width > HomeScreen.phoneMaxWidth;
    final app = laptop ? const HomeScreen(presenterFirst: true) : const PhoneShell();
    final account = ServicesScope.of(context).account;
    return account == null ? app : _SignInFirst(account: account, app: app);
  }
}

class _SignInFirst extends StatefulWidget {
  const _SignInFirst({required this.account, required this.app});
  final AccountService account;

  /// The phone app or the laptop page.
  final Widget app;

  @override
  State<_SignInFirst> createState() => _SignInFirstState();
}

class _SignInFirstState extends State<_SignInFirst> {
  /// In the app. Set by sign-in when it is done (an employee first joins the company), not by the
  /// account alone; signing out brings sign-in back.
  late bool _inside = widget.account.isSignedIn;

  @override
  void initState() {
    super.initState();
    widget.account.addListener(_onAccount);
  }

  @override
  void dispose() {
    widget.account.removeListener(_onAccount);
    super.dispose();
  }

  void _onAccount() {
    if (!widget.account.isSignedIn && _inside) setState(() => _inside = false);
  }

  @override
  Widget build(BuildContext context) => _inside
      ? widget.app
      : SignInScreen(account: widget.account, onDone: () => setState(() => _inside = true));
}
