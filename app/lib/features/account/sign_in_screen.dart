import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/account/account_service.dart';
import '../../l10n/app_localizations.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _codePattern = RegExp(r'^\d{6,10}$');

/// Passwordless sign-in: a code sent by email, or Google. No password to
/// remember and nothing that relies on hearing (WCAG 2.2, 3.3.8).
/// Closes itself once the user is signed in.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.account});
  final AccountService account;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  String? _sentTo;
  String? _error;
  bool _busy = false;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    // Google and the email link finish outside this screen.
    widget.account.addListener(_closeWhenSignedIn);
  }

  @override
  void dispose() {
    widget.account.removeListener(_closeWhenSignedIn);
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  void _closeWhenSignedIn() {
    if (!widget.account.isSignedIn || _closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object {
      if (mounted) setState(() => _error = AppLocalizations.of(context).signInFailed);
    }
    if (mounted) setState(() => _busy = false);
  }

  void _sendCode() {
    final email = _email.text.trim();
    if (!_emailPattern.hasMatch(email)) {
      setState(() => _error = AppLocalizations.of(context).signInInvalidEmail);
      return;
    }
    _run(() async {
      await widget.account.sendEmailCode(email);
      if (mounted) setState(() => _sentTo = email);
    });
  }

  void _verify() {
    final code = _code.text.trim();
    if (!_codePattern.hasMatch(code)) {
      setState(() => _error = AppLocalizations.of(context).signInInvalidCode);
      return;
    }
    _run(() => widget.account.verifyEmailCode(_sentTo!, code));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sentTo = _sentTo;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.signIn)),
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(l10n.signInIntro, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 24),
              if (sentTo == null) ...[
                TextField(
                  controller: _email,
                  decoration: InputDecoration(labelText: l10n.signInEmailLabel, border: const OutlineInputBorder()),
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  autocorrect: false,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendCode(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: _busy ? null : _sendCode,
                  child: Text(l10n.signInSendCode),
                ),
              ] else ...[
                Semantics(liveRegion: true, child: Text(l10n.signInCodeSent(sentTo), style: theme.textTheme.bodyLarge)),
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  decoration: InputDecoration(labelText: l10n.signInCodeLabel, border: const OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: _busy ? null : _verify,
                  child: Text(l10n.signInVerify),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _sentTo = null;
                            _code.clear();
                            _error = null;
                          }),
                  child: Text(l10n.signInOtherEmail),
                ),
              ],
              if (_error case final error?) ...[
                const SizedBox(height: 12),
                // Icon + text, so the error never depends on colour alone.
                Semantics(
                  liveRegion: true,
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text(error, style: theme.textTheme.bodyLarge)),
                    ],
                  ),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              const SizedBox(height: 32),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text(l10n.signInOr)),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: _busy ? null : () => _run(widget.account.signInWithGoogle),
                icon: const Icon(Icons.account_circle),
                label: Text(l10n.signInGoogle),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
