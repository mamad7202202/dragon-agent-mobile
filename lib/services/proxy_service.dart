import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Which traffic class a request belongs to — used to decide proxy routing.
enum ProxyScope { ai, tools }

/// User-configured proxy.
///
/// [server] accepts `host`, `host:port`, or `scheme://[user:pass@]host[:port]`.
/// HTTP and HTTPS proxies are supported through dart:io's native
/// `HttpClient.findProxy` (CONNECT tunneling) — no extra packages.
class ProxyConfig {
  bool enabled;
  String server;

  /// Route AI/provider traffic through the proxy.
  bool ai;

  /// Route integration traffic (GitHub, Cloudflare, skills, updates).
  bool integrations;

  /// When non-empty, only this provider name is proxied (AI scope).
  String aiProvider;

  ProxyConfig({
    this.enabled = false,
    this.server = '',
    this.ai = true,
    this.integrations = true,
    this.aiProvider = '',
  });

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'server': server,
        'ai': ai,
        'integrations': integrations,
        'ai_provider': aiProvider,
      };

  factory ProxyConfig.fromJson(Map<String, dynamic> j) => ProxyConfig(
        enabled: j['enabled'] as bool? ?? false,
        server: j['server'] as String? ?? '',
        ai: j['ai'] as bool? ?? true,
        integrations: j['integrations'] as bool? ?? true,
        aiProvider: j['ai_provider'] as String? ?? '',
      );

  bool get hasServer => _normalize(server).host.isNotEmpty;

  /// True when a request of [scope] (optionally from provider [provider])
  /// should go through the proxy right now.
  bool applies(ProxyScope scope, {String? provider}) {
    if (!enabled || !hasServer) return false;
    switch (scope) {
      case ProxyScope.ai:
        if (!ai) return false;
        return aiProvider.isEmpty || aiProvider == (provider ?? '');
      case ProxyScope.tools:
        return integrations;
    }
  }
}

/// Parses loose proxy input into scheme/user/host/port.
({String scheme, String userinfo, String host, int port}) _normalize(
    String raw) {
  var s = raw.trim();
  if (s.isEmpty) return (scheme: 'http', userinfo: '', host: '', port: 0);
  var scheme = 'http';
  final schemeMatch = RegExp(r'^([a-zA-Z][a-zA-Z0-9+.-]*)://').firstMatch(s);
  if (schemeMatch != null) {
    scheme = schemeMatch.group(1)!.toLowerCase();
    s = s.substring(schemeMatch.end);
  }
  var userinfo = '';
  final at = s.lastIndexOf('@');
  if (at >= 0) {
    userinfo = s.substring(0, at);
    s = s.substring(at + 1);
  }
  // strip path
  final slash = s.indexOf('/');
  if (slash >= 0) s = s.substring(0, slash);
  String host = s;
  var port = scheme == 'https' ? 443 : 8080;
  if (s.startsWith('[')) {
    // ipv6 literal
    final close = s.indexOf(']');
    if (close > 0) {
      host = s.substring(0, close + 1);
      final rest = s.substring(close + 1);
      if (rest.startsWith(':')) port = int.tryParse(rest.substring(1)) ?? port;
    }
  } else {
    final colon = s.lastIndexOf(':');
    if (colon >= 0) {
      final p = int.tryParse(s.substring(colon + 1));
      if (p != null && p > 0) {
        host = s.substring(0, colon);
        port = p;
      }
    }
  }
  return (scheme: scheme, userinfo: userinfo, host: host, port: port);
}

/// Central proxy-aware http client provider.
///
/// Two long-lived clients (direct + proxied); the proxied one is rebuilt when
/// the config revision changes so edits apply to the next request.
abstract class ProxyHttp {
  static ProxyConfig config = ProxyConfig();
  static int _rev = 0;
  static int _builtRev = -1;

  static final http.Client direct = http.Client();
  static http.Client? _proxied;

  /// Picks the client for a request. Always returns an open client.
  static http.Client forScope(ProxyScope scope, {String? provider}) {
    if (!config.applies(scope, provider: provider)) return direct;
    if (_builtRev != _rev || _proxied == null) {
      _proxied?.close();
      _proxied = _build(config);
      _builtRev = _rev;
    }
    return _proxied!;
  }

  /// Applies a new config; in-flight requests on the old proxied client keep
  /// running, everything after this goes through the new settings.
  static void update(ProxyConfig c) {
    config = c;
    _rev++;
  }

  /// One-off reachability probe through [c] — returns null on success,
  /// or an error description. Independent of scope switches.
  static Future<String?> test(ProxyConfig c) async {
    if (!c.hasServer) return 'Enter a server address first';
    final probe = _build(c);
    try {
      final res = await probe
          .get(Uri.parse('https://api.github.com/zen'))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode == 200) return null;
      return 'HTTP ${res.statusCode} through the proxy';
    } catch (e) {
      return e.toString();
    } finally {
      probe.close();
    }
  }

  static http.Client _build(ProxyConfig c) {
    final n = _normalize(c.server);
    final host = n.host.startsWith('[')
        ? n.host.substring(1, n.host.length - 1)
        : n.host;

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20)
      ..findProxy = (_) =>
          '${n.scheme == 'https' ? 'SSL' : 'PROXY'} $host:${n.port}';

    if (n.userinfo.isNotEmpty) {
      final sep = n.userinfo.indexOf(':');
      final user = sep < 0 ? n.userinfo : n.userinfo.substring(0, sep);
      final pass = sep < 0 ? '' : n.userinfo.substring(sep + 1);
      client.addProxyCredentials(
          host, n.port, '', HttpClientBasicCredentials(user, pass));
    }
    return IOClient(client);
  }

  static void dispose() {
    direct.close();
    _proxied?.close();
    _proxied = null;
  }
}
