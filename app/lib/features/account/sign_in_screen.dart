import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/account/account_service.dart';
import '../../core/org/org_store.dart';
import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/echo_style.dart';
import '../../widgets/echo_logo.dart';
import '../../widgets/glass.dart';
import '../../widgets/grouped_list.dart';
import '../organization/org_screen.dart';
import '../presenter/presenter_screen.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
final _codePattern = RegExp(r'^\d{6,10}$');

/// Who is signing in: the admin who runs the team, or an employee joining with the company code.
enum SignInRole { admin, employee }

/// The company code as typed, without spaces or dashes: 8 letters and digits.
String _plainCompanyCode(String typed) => typed.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

/// Passwordless sign-in: a code sent by email, or Google for the admin. No password to remember
/// and nothing that relies on hearing (WCAG 2.2, 3.3.8).
/// docs/superpowers/specs/2026-10-23-login-cod-companie-design.md: the admin lands on the company
/// screen; the employee gives the company code, their name and how they use Echo, and joins.
///
/// With [onDone] it is the phone app's first screen (EchoHome): no back button, a way in without an
/// account for the presenter (rule 6), and [onDone] instead of closing, once the person is in.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.account, this.onDone});
  final AccountService account;
  final VoidCallback? onDone;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _companyCode = TextEditingController();
  final _name = TextEditingController();
  SignInRole _role = SignInRole.admin;
  MemberExperience? _experience;
  String? _sentTo;
  String? _error;
  bool _busy = false;
  bool _closed = false;

  /// Signed in as an employee, but the company code did not work: they type it again.
  bool _joinPending = false;

  /// A demo account is signing in with its password: it goes straight in, already in its company.
  bool _demo = false;

  @override
  void initState() {
    super.initState();
    // Google and the email link finish outside this screen.
    widget.account.addListener(_onAccountChanged);
  }

  @override
  void dispose() {
    widget.account.removeListener(_onAccountChanged);
    _email.dispose();
    _code.dispose();
    _companyCode.dispose();
    _name.dispose();
    super.dispose();
  }

  /// The admin goes on to the company screen (where the company is made the first time).
  /// The employee's joining runs after the email code is confirmed, in [_verify].
  void _onAccountChanged() {
    if (!widget.account.isSignedIn || _closed || _demo || !mounted || _role != SignInRole.admin) return;
    _closed = true;
    final organizations = ServicesScope.of(context).organizations;
    final navigator = Navigator.of(context);
    final company = organizations == null
        ? null
        : MaterialPageRoute<void>(builder: (_) => OrgScreen(organizations: organizations));
    if (widget.onDone case final done?) {
      // The app takes this screen's place; the company screen opens over it.
      done();
      if (company != null) navigator.push(company);
    } else if (company != null) {
      navigator.pushReplacement(company);
    } else {
      navigator.pop();
    }
  }

  /// In: back to the app (first screen) or to where sign-in was opened from.
  void _finish(NavigatorState navigator) {
    _closed = true;
    if (widget.onDone case final done?) {
      done();
    } else {
      navigator.pop();
    }
  }

  Future<void> _run(Future<void> Function() action, {String? failure}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Object {
      if (mounted) setState(() => _error = failure ?? AppLocalizations.of(context).signInFailed);
    }
    if (mounted) setState(() => _busy = false);
  }

  /// What the employee must give, checked before any email leaves; null when all is there.
  String? _missingForEmployee(AppLocalizations l10n) {
    if (_plainCompanyCode(_companyCode.text).length != 8) return l10n.companyCodeInvalid;
    if (_name.text.trim().isEmpty) return l10n.joinNameMissing;
    if (_experience == null) return l10n.joinExperienceMissing;
    return null;
  }

  void _sendCode() {
    final l10n = AppLocalizations.of(context);
    final missing = _role == SignInRole.employee ? _missingForEmployee(l10n) : null;
    final email = _email.text.trim();
    if (missing != null || !_emailPattern.hasMatch(email)) {
      setState(() => _error = missing ?? l10n.signInInvalidEmail);
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
    _run(() async {
      await widget.account.verifyEmailCode(_sentTo!, code);
      if (_role == SignInRole.employee && mounted) await _join();
    });
  }

  /// Joins the company of the code; a wrong code keeps the employee here, signed in, to fix it.
  Future<void> _join() async {
    final l10n = AppLocalizations.of(context);
    final organizations = ServicesScope.of(context).organizations;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (organizations == null) {
      _finish(navigator);
      return;
    }
    String? orgId;
    try {
      orgId = await organizations.store.joinWithCode(_companyCode.text, _name.text, _experience!);
    } on JoinCodeTooManyAttempts {
      _stayToFix(l10n.joinTooMany);
      return;
    }
    if (orgId == null) {
      _stayToFix(l10n.joinWrongCode);
      return;
    }
    await organizations.refresh();
    final joined = organizations.memberships.where((m) => m.orgId == orgId).firstOrNull;
    if (joined != null) messenger.showSnackBar(SnackBar(content: Text(l10n.joinDone(joined.orgName))));
    _finish(navigator);
  }

  /// The demo accounts' way in (tools/seed_test_accounts.py), in a sheet; true once signed in.
  Future<void> _openDemoSignIn() async {
    final navigator = Navigator.of(context);
    final signedIn = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DemoSignInSheet(
        signIn: (email, password) async {
          _demo = true;
          try {
            await widget.account.signInWithPassword(email, password);
          } on Object {
            _demo = false;
            rethrow;
          }
        },
      ),
    );
    if (signedIn == true && mounted) _finish(navigator);
  }

  void _stayToFix(String error) {
    if (!mounted) return;
    setState(() {
      _joinPending = true;
      _error = error;
    });
  }

  void _retryJoin() {
    final l10n = AppLocalizations.of(context);
    if (_plainCompanyCode(_companyCode.text).length != 8) {
      setState(() => _error = l10n.companyCodeInvalid);
      return;
    }
    _run(_join, failure: l10n.orgError);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    final sentTo = _sentTo;
    final employee = _role == SignInRole.employee;
    final big = FilledButton.styleFrom(minimumSize: const Size.fromHeight(52));

    Widget companyCodeField() => TextField(
          controller: _companyCode,
          decoration: InputDecoration(
            labelText: l10n.companyCodeLabel,
            hintText: 'ABCD-EFGH',
            // Thin, so the example never looks like a code already typed.
            hintStyle: theme.textTheme.titleMedium?.copyWith(
              letterSpacing: 2,
              fontWeight: FontWeight.w400,
              color: palette.muted,
            ),
          ),
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          inputFormatters: [LengthLimitingTextInputFormatter(12)],
          style: theme.textTheme.titleMedium?.copyWith(letterSpacing: 2),
          textInputAction: TextInputAction.next,
        );

    Widget experienceChoice(MemberExperience value, IconData icon, String title, String hint) => EchoGroupRow(
          leading: RowIcon(icon),
          title: title,
          subtitle: [hint],
          selected: _experience == value,
          trailing: _experience == value
              ? Icon(Icons.check_rounded, color: palette.accent)
              : const SizedBox(width: 24),
          onTap: () => setState(() {
            _experience = value;
            _error = null;
          }),
        );

    final emailField = TextField(
      controller: _email,
      decoration: InputDecoration(labelText: l10n.signInEmailLabel),
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      autocorrect: false,
      textInputAction: employee ? TextInputAction.next : TextInputAction.send,
      onSubmitted: employee ? null : (_) => _sendCode(),
    );

    return Scaffold(
      // Opened from the app: only the back button; as the first screen: nothing above the logo.
      appBar: widget.onDone == null ? AppBar(backgroundColor: Colors.transparent) : null,
      body: SafeArea(
        child: AutofillGroup(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 32),
            children: [
              Center(child: EchoLogo(height: 96, semanticLabel: l10n.appTitle)),
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  l10n.signInWelcome,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(color: palette.text),
                ),
              ),
              const SizedBox(height: 28),
              if (sentTo == null && !_joinPending) ...[
                GlassSegmented<SignInRole>(
                  semanticLabel: l10n.signInRoleLabel,
                  selected: _role,
                  onChanged: (role) => setState(() {
                    _role = role;
                    _error = null;
                  }),
                  options: [
                    (SignInRole.admin, Icons.admin_panel_settings_outlined, Icons.admin_panel_settings, l10n.signInRoleAdmin),
                    (SignInRole.employee, Icons.badge_outlined, Icons.badge, l10n.signInRoleEmployee),
                  ],
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    employee ? l10n.signInEmployeeIntro : l10n.signInAdminIntro,
                    style: theme.textTheme.bodyLarge?.copyWith(color: palette.muted),
                  ),
                ),
                const SizedBox(height: 24),
                emailField,
                const SizedBox(height: 16),
                if (employee) ...[
                  companyCodeField(),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _name,
                    decoration: InputDecoration(labelText: l10n.joinNameLabel),
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    inputFormatters: [LengthLimitingTextInputFormatter(100)],
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: 28),
                  EchoGroup(
                    title: l10n.joinExperienceTitle,
                    rows: [
                      experienceChoice(MemberExperience.visual, Icons.closed_caption_outlined, l10n.experienceVisual,
                          l10n.experienceVisualHint),
                      experienceChoice(MemberExperience.standard, Icons.record_voice_over_outlined,
                          l10n.experienceStandard, l10n.experienceStandardHint),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // What the company will see, said before anything is sent (GDPR art. 13).
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(child: Icon(Icons.info_outline_rounded, color: palette.muted)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(l10n.joinPrivacy, style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted))),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
                FilledButton(style: big, onPressed: _busy ? null : _sendCode, child: Text(l10n.signInSendCode)),
              ] else if (_joinPending) ...[
                companyCodeField(),
                const SizedBox(height: 16),
                FilledButton(style: big, onPressed: _busy ? null : _retryJoin, child: Text(l10n.joinRetry)),
              ] else ...[
                Semantics(liveRegion: true, child: Text(l10n.signInCodeSent(sentTo!), style: theme.textTheme.bodyLarge)),
                const SizedBox(height: 16),
                TextField(
                  controller: _code,
                  decoration: InputDecoration(labelText: l10n.signInCodeLabel),
                  keyboardType: TextInputType.number,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _verify(),
                ),
                const SizedBox(height: 16),
                FilledButton(style: big, onPressed: _busy ? null : _verify, child: Text(l10n.signInVerify)),
                const SizedBox(height: 4),
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
                const SizedBox(height: 16),
                // Icon + text, so the error never depends on colour alone.
                Semantics(
                  liveRegion: true,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
                      const SizedBox(width: 10),
                      Expanded(child: Text(error, style: theme.textTheme.bodyLarge)),
                    ],
                  ),
                ),
              ],
              if (_busy) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator()),
              ],
              if (!employee && sentTo == null) ...[
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
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  onPressed: _busy ? null : () => _run(widget.account.signInWithGoogle),
                  icon: const Icon(Icons.account_circle_outlined),
                  label: Text(l10n.signInGoogle),
                ),
              ],
              if (sentTo == null && !_joinPending) ...[
                const SizedBox(height: 16),
                Center(
                  child: TextButton.icon(
                    onPressed: _busy ? null : _openDemoSignIn,
                    icon: const Icon(Icons.science_outlined),
                    label: Text(l10n.demoSignInLink),
                  ),
                ),
              ],
              if (widget.onDone != null && sentTo == null && !_joinPending) ...[
                const SizedBox(height: 4),
                Center(
                  child: TextButton.icon(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PresenterScreen())),
                    icon: const Icon(Icons.co_present_outlined),
                    label: Text(l10n.signInPresentWithout, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Email and password for a demo account; closes with true once signed in.
class _DemoSignInSheet extends StatefulWidget {
  const _DemoSignInSheet({required this.signIn});
  final Future<void> Function(String email, String password) signIn;

  @override
  State<_DemoSignInSheet> createState() => _DemoSignInSheetState();
}

class _DemoSignInSheetState extends State<_DemoSignInSheet> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _failed = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _failed = false;
    });
    try {
      await widget.signIn(_email.text, _password.text);
      navigator.pop(true);
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final palette = EchoPalette.of(context);
    return Padding(
      // Above the keyboard.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Semantics(
              header: true,
              child: Text(l10n.demoSignInTitle, textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.demoSignInHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: 20),
            AutofillGroup(
              child: Column(
                children: [
                  TextField(
                    controller: _email,
                    decoration: InputDecoration(labelText: l10n.signInEmailLabel),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _password,
                    decoration: InputDecoration(labelText: l10n.demoSignInPassword),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _busy ? null : _go(),
                  ),
                ],
              ),
            ),
            if (_failed) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline_rounded, color: theme.colorScheme.error),
                    const SizedBox(width: 10),
                    Expanded(child: Text(l10n.demoSignInFailed, style: theme.textTheme.bodyLarge)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _busy ? null : _go,
              child: Text(l10n.demoSignInGo),
            ),
          ],
        ),
      ),
    );
  }
}
