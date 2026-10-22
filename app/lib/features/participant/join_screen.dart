import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/join_link.dart';
import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
import '../../theme/echo_style.dart';
import '../../widgets/pressable.dart';
import 'participant_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _form = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _server = TextEditingController();
  bool _serverFilled = false;
  bool _editServer = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_serverFilled) {
      _serverFilled = true;
      _server.text = defaultServer(SettingsScope.of(context)).toString();
    }
  }

  @override
  void dispose() {
    _code.dispose();
    _server.dispose();
    super.dispose();
  }

  void _open(JoinLink link) {
    final settings = SettingsScope.of(context);
    settings.update((s) => s.serverUrl = link.server.toString());
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => ParticipantScreen(link: link)));
  }

  bool _validServer(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
  }

  void _submit() {
    // While folded away the server field holds defaultServer(), which is always valid.
    if (!_form.currentState!.validate()) return;
    final server = Uri.parse(_server.text.trim());
    _open(JoinLink(server: Uri(scheme: server.scheme, host: server.host, port: server.port), code: _code.text.trim().toUpperCase()));
  }

  Future<void> _scan() async {
    final link = await Navigator.of(context).push<JoinLink>(MaterialPageRoute(builder: (_) => const _QrScanScreen()));
    if (link != null && mounted) _open(link);
  }

  InputDecoration _field(EchoPalette p, {String? hint}) {
    OutlineInputBorder border(Color color, double width) =>
        OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: color, width: width));
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: p.raised,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: border(p.control, 1),
      focusedBorder: border(p.accent, 2),
      errorBorder: border(Theme.of(context).colorScheme.error, 1),
      focusedErrorBorder: border(Theme.of(context).colorScheme.error, 2),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = EchoPalette.of(context);
    final theme = Theme.of(context);
    final label = theme.textTheme.titleSmall?.copyWith(color: palette.text, fontWeight: FontWeight.w600);

    return Scaffold(
      backgroundColor: palette.ground,
      appBar: AppBar(
        backgroundColor: palette.ground,
        foregroundColor: palette.text,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: false,
        title: Text(l10n.joinTitle, style: theme.textTheme.titleLarge?.copyWith(color: palette.text, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  Text(l10n.joinIntro, style: theme.textTheme.bodyLarge?.copyWith(color: palette.text)),
                  const SizedBox(height: 24),
                  // The label sits above the field, never inside it.
                  Text(l10n.joinCodeLabel, style: label),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _code,
                    decoration: _field(palette),
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    maxLength: 6,
                    style: theme.textTheme.headlineSmall?.copyWith(color: palette.text, letterSpacing: 6),
                    validator: (value) => JoinLink.isValidCode(value ?? '') ? null : l10n.joinInvalidCode,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: Pressable(
                      child: FilledButton(style: EchoButtons.primary(palette), onPressed: _submit, child: Text(l10n.joinButton)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      style: EchoButtons.link(palette, flush: true),
                      onPressed: _scan,
                      icon: Icon(Icons.qr_code_scanner, color: palette.muted),
                      label: Text(l10n.joinScan),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _ServerPanel(
                    palette: palette,
                    editing: _editServer,
                    onChange: () => setState(() => _editServer = true),
                    current: _server.text,
                    field: TextFormField(
                      controller: _server,
                      decoration: _field(palette, hint: l10n.joinServerHint),
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      style: theme.textTheme.bodyLarge?.copyWith(color: palette.text),
                      validator: (value) => _validServer(value ?? '') ? null : l10n.joinInvalidServer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The server address: rarely changed, so it shows its value and opens a field only on request.
class _ServerPanel extends StatelessWidget {
  const _ServerPanel({
    required this.palette,
    required this.editing,
    required this.onChange,
    required this.current,
    required this.field,
  });

  final EchoPalette palette;
  final bool editing;
  final VoidCallback onChange;
  final String current;
  final Widget field;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final highContrast = SettingsScope.of(context).highContrast;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: highContrast ? Border.all(color: palette.border, width: 2) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.joinServerLabel, style: theme.textTheme.titleSmall?.copyWith(color: palette.text, fontWeight: FontWeight.w600)),
                    if (!editing) ...[
                      const SizedBox(height: 2),
                      Text(current, style: theme.textTheme.bodyMedium?.copyWith(color: palette.muted)),
                    ],
                  ],
                ),
              ),
              if (!editing) TextButton(style: EchoButtons.link(palette), onPressed: onChange, child: Text(l10n.joinServerChange)),
            ],
          ),
          if (editing) ...[
            const SizedBox(height: 8),
            Padding(padding: const EdgeInsets.only(right: 8), child: field),
          ],
        ],
      ),
    );
  }
}

class _QrScanScreen extends StatefulWidget {
  const _QrScanScreen();

  @override
  State<_QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<_QrScanScreen> {
  bool _done = false;
  bool _showedInvalid = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final link = JoinLink.parse(barcode.rawValue ?? '');
      if (link != null) {
        _done = true;
        Navigator.of(context).pop(link);
        return;
      }
    }
    if (!_showedInvalid) {
      _showedInvalid = true;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).joinInvalidQr)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).joinScan)),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}
