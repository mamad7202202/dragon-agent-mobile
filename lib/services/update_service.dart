import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

/// Information about a newer release on GitHub.
class UpdateInfo {
  final String version;
  final String apkUrl;
  final String releaseUrl;
  final DateTime? publishedAt;

  const UpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.releaseUrl,
    this.publishedAt,
  });
}

/// Checks GitHub releases and manages in-app self-update on Android.
class UpdateService {
  static const _repo = 'mamad7202202/dragon-agent-mobile';
  static const _apiUrl =
      'https://api.github.com/repos/$_repo/releases/tags/latest';

  final http.Client _http = http.Client();

  /// Current app version, e.g. "1.1.0".
  Future<String> currentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Returns info about a newer release, or null when up-to-date/unavailable.
  Future<UpdateInfo?> check(String currentVersion) async {
    try {
      final res = await _http
          .get(
            Uri.parse(_apiUrl),
            headers: {
              'Accept': 'application/vnd.github+json',
              'User-Agent': 'dragon-agent-mobile',
            },
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return null;

      final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final tag = (j['tag_name'] as String? ?? '').replaceFirst('v', '');
      if (tag.isEmpty || !isNewer(tag, currentVersion)) return null;

      final assets = (j['assets'] as List? ?? []).cast<Map<String, dynamic>>();
      String? url;
      for (final a in assets) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (!name.endsWith('.apk')) continue;
        if (name.contains('arm64')) {
          url = a['browser_download_url'] as String?;
          break;
        }
        url ??= a['browser_download_url'] as String?;
      }
      if (url == null) return null;

      return UpdateInfo(
        version: tag,
        apkUrl: url,
        releaseUrl: 'https://github.com/$_repo/releases/latest',
        publishedAt:
            DateTime.tryParse(j['published_at'] as String? ?? ''),
      );
    } catch (_) {
      return null;
    }
  }

  /// Numeric semver-ish comparison: true when [latest] > [current].
  bool isNewer(String latest, String current) {
    List<int> parse(String v) => v
        .replaceFirst(RegExp(r'^v'), '')
        .split(RegExp(r'[+\-]'))
        .first
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final a = parse(latest);
    final b = parse(current);
    for (var i = 0; i < 3; i++) {
      final av = i < a.length ? a[i] : 0;
      final bv = i < b.length ? b[i] : 0;
      if (av != bv) return av > bv;
    }
    return false;
  }

  /// Downloads the APK with progress 0.0..1.0, returns the file path.
  Future<String> download(
    String url,
    void Function(double progress)? onProgress,
  ) async {
    final dir = Platform.isAndroid
        ? (await getExternalStorageDirectory() ??
            await getApplicationSupportDirectory())
        : await getApplicationSupportDirectory();
    final file = File('${dir.path}/dragon-agent-update.apk');
    if (await file.exists()) await file.delete();

    final req = http.Request('GET', Uri.parse(url));
    final res = await _http.send(req).timeout(const Duration(minutes: 10));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} while downloading update');
    }
    final total = res.contentLength ?? 0;
    final sink = file.openWrite();
    var received = 0;
    try {
      await for (final chunk in res.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    return file.path;
  }

  /// Triggers the Android package installer for [apkPath].
  /// On other platforms opens the GitHub releases page.
  Future<String?> install(String apkPath, {String? fallbackUrl}) async {
    if (Platform.isAndroid) {
      var status = await Permission.requestInstallPackages.status;
      if (!status.isGranted) {
        status = await Permission.requestInstallPackages.request();
      }
      if (!status.isGranted) {
        return 'مجوز نصب داده نشد — دوباره تلاش کن';
      }
      final result = await OpenFilex.open(
        apkPath,
        type: 'application/vnd.android.package-archive',
      );
      if (result.type.toString().contains('error') ||
          result.type.toString().contains('noApp')) {
        return result.message;
      }
      return null;
    }
    if (fallbackUrl != null) {
      await launchUrl(Uri.parse(fallbackUrl),
          mode: LaunchMode.externalApplication);
    }
    return null;
  }

  void dispose() => _http.close();
}
