import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/join_link.dart';
import '../../core/services.dart';
import '../../l10n/app_localizations.dart';
import '../../settings/app_settings.dart';
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

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final server = Uri.parse(_server.text.trim());
    _open(JoinLink(server: Uri(scheme: server.scheme, host: server.host, port: server.port), code: _code.text.trim().toUpperCase()));
  }

  Future<void> _scan() async {
    final link = await Navigator.of(context).push<JoinLink>(MaterialPageRoute(builder: (_) => const _QrScanScreen()));
    if (link != null && mounted) _open(link);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.joinTitle)),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(64)),
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(l10n.joinScan),
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _code,
                decoration: InputDecoration(labelText: l10n.joinCodeLabel, border: const OutlineInputBorder()),
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                maxLength: 6,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(letterSpacing: 4),
                validator: (value) => JoinLink.isValidCode(value ?? '') ? null : l10n.joinInvalidCode,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _server,
                decoration: InputDecoration(
                  labelText: l10n.joinServerLabel,
                  hintText: l10n.joinServerHint,
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
                validator: (value) {
                  final uri = Uri.tryParse(value?.trim() ?? '');
                  final ok = uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty;
                  return ok ? null : l10n.joinInvalidServer;
                },
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: _submit,
                child: Text(l10n.joinButton),
              ),
            ],
          ),
        ),
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
