/// What the presenter's QR code encodes: `<server>/?code=ABC123`. Opening the
/// link in a browser still lands on the server, so it works without the app too.
class JoinLink {
  const JoinLink({required this.server, required this.code});

  final Uri server;
  final String code;

  static const codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final _codePattern = RegExp('^[$codeAlphabet]{6}\$');

  static bool isValidCode(String code) => _codePattern.hasMatch(code.trim().toUpperCase());

  Uri toUri() => server.replace(path: '/', queryParameters: {'code': code});

  static JoinLink? parse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) return null;
    final code = (uri.queryParameters['code'] ?? '').toUpperCase();
    if (!isValidCode(code)) return null;
    return JoinLink(server: Uri(scheme: uri.scheme, host: uri.host, port: uri.port), code: code);
  }

  /// WebSocket address of this meeting for the given role.
  Uri socketUri(String role) => server.replace(
        scheme: server.scheme == 'https' ? 'wss' : 'ws',
        path: '/ws/$code',
        queryParameters: {'role': role},
      );
}
