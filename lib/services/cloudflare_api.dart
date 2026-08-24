import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

/// Direct Cloudflare API v4 integration — the agent manages the user's
/// account: KV namespaces, D1 databases and Worker deployments.
class CloudflareService {
  String token = '';
  bool get connected => token.trim().isNotEmpty;

  final http.Client _client = http.Client();

  static const toolDefs = <Map<String, Object>>[
    {
      'name': 'cf_accounts',
      'description': 'List the user\'s Cloudflare accounts with their ids — '
          'call this first; every other tool needs an account_id.',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
    {
      'name': 'cf_create_kv',
      'description': 'Create a Workers KV namespace.',
      'parameters': {
        'type': 'object',
        'properties': {
          'account_id': {'type': 'string'},
          'title': {'type': 'string'},
        },
        'required': ['account_id', 'title'],
      },
    },
    {
      'name': 'cf_kv_write',
      'description': 'Write a value into a KV namespace.',
      'parameters': {
        'type': 'object',
        'properties': {
          'account_id': {'type': 'string'},
          'namespace_id': {'type': 'string'},
          'key': {'type': 'string'},
          'value': {'type': 'string'},
        },
        'required': ['account_id', 'namespace_id', 'key', 'value'],
      },
    },
    {
      'name': 'cf_kv_read',
      'description': 'Read one value from a KV namespace.',
      'parameters': {
        'type': 'object',
        'properties': {
          'account_id': {'type': 'string'},
          'namespace_id': {'type': 'string'},
          'key': {'type': 'string'},
        },
        'required': ['account_id', 'namespace_id', 'key'],
      },
    },
    {
      'name': 'cf_create_d1',
      'description': 'Create a D1 SQL database.',
      'parameters': {
        'type': 'object',
        'properties': {
          'account_id': {'type': 'string'},
          'name': {'type': 'string'},
        },
        'required': ['account_id', 'name'],
      },
    },
    {
      'name': 'cf_d1_query',
      'description':
          'Run SQL against a D1 database (CREATE TABLE, INSERT, SELECT…).',
      'parameters': {
        'type': 'object',
        'properties': {
          'account_id': {'type': 'string'},
          'database_id': {'type': 'string'},
          'sql': {'type': 'string'},
          'params': {
            'type': 'array',
            'description': 'Bound parameters. Optional.',
          },
        },
        'required': ['account_id', 'database_id', 'sql'],
      },
    },
    {
      'name': 'cf_deploy_worker',
      'description':
          'Deploy (create or update) a Cloudflare Worker from a single ES-module '
              'JavaScript source. Use export default { fetch(request, env) } style.',
      'parameters': {
        'type': 'object',
        'properties': {
          'account_id': {'type': 'string'},
          'name': {'type': 'string'},
          'script': {'type': 'string', 'description': 'Full JS module source.'},
        },
        'required': ['account_id', 'name', 'script'],
      },
    },
    {
      'name': 'cf_list_workers',
      'description': 'List deployed Workers in an account.',
      'parameters': {
        'type': 'object',
        'properties': {
          'account_id': {'type': 'string'},
        },
        'required': ['account_id'],
      },
    },
  ];

  Future<Map<String, dynamic>> _req(String method, String path,
      {Object? body}) async {
    final req = http.Request(
        method, Uri.parse('https://api.cloudflare.com/client/v4$path'))
      ..headers.addAll({
        'Authorization': 'Bearer ${token.trim()}',
        'Content-Type': 'application/json',
      });
    if (body != null) req.body = jsonEncode(body);
    final res = await _client.send(req).timeout(const Duration(seconds: 30));
    final text = await res.stream.bytesToString();
    Map<String, dynamic> j;
    try {
      j = jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Cloudflare HTTP ${res.statusCode}');
    }
    if (j['success'] != true) {
      final errs = (j['errors'] as List?) ?? const [];
      final msg = errs.isNotEmpty
          ? ((errs.first as Map)['message'] ?? 'unknown error')
          : 'HTTP ${res.statusCode}';
      throw Exception('Cloudflare · $msg');
    }
    return j;
  }

  Future<String> handleTool(String name, Map<String, dynamic> a) async {
    switch (name) {
      case 'cf_accounts':
        final r = await _req('GET', '/accounts');
        final out = (r['result'] as List).map((x) => {
              'id': x['id'],
              'name': x['name'],
            }).toList();
        return _json({'ok': true, 'accounts': out});

      case 'cf_create_kv':
        final r = await _req(
            'POST', '/accounts/${a['account_id']}/storage/kv/namespaces',
            body: {'title': a['title']});
        return _json({
          'ok': true,
          'namespace_id': (r['result'] as Map)['id'],
          'title': a['title'],
        });

      case 'cf_kv_write':
        final res = await _client
            .put(
              Uri.parse(
                  'https://api.cloudflare.com/client/v4/accounts/${a['account_id']}/storage/kv/namespaces/${a['namespace_id']}/values/${Uri.encodeComponent(a['key'] as String)}'),
              headers: {
                'Authorization': 'Bearer ${token.trim()}',
                'Content-Type': 'text/plain',
              },
              body: a['value'].toString(),
            )
            .timeout(const Duration(seconds: 30));
        final j = jsonDecode(res.body) as Map<String, dynamic>;
        if (j['success'] != true) {
          throw Exception('Cloudflare · KV write failed');
        }
        return _json({'ok': true, 'key': a['key']});

      case 'cf_kv_read':
        final res = await _client
            .get(
              Uri.parse(
                  'https://api.cloudflare.com/client/v4/accounts/${a['account_id']}/storage/kv/namespaces/${a['namespace_id']}/values/${Uri.encodeComponent(a['key'] as String)}'),
              headers: {'Authorization': 'Bearer ${token.trim()}'},
            )
            .timeout(const Duration(seconds: 30));
        if (res.statusCode != 200) {
          return _json({'ok': false, 'error': 'HTTP ${res.statusCode}'});
        }
        return _json({
          'ok': true,
          'key': a['key'],
          'value': _clip(res.body, 4000),
        });

      case 'cf_create_d1':
        final r = await _req(
            'POST', '/accounts/${a['account_id']}/d1/database',
            body: {'name': a['name']});
        final db = r['result'] as Map;
        return _json({
          'ok': true,
          'database_id': db['uuid'],
          'name': db['name'],
        });

      case 'cf_d1_query':
        final r = await _req(
            'POST', '/accounts/${a['account_id']}/d1/database/${a['database_id']}/query',
            body: {
              'sql': a['sql'],
              if (a['params'] != null) 'params': a['params'],
            });
        return _json({
          'ok': true,
          'results': _clip(jsonEncode(r['result']), 5000),
        });

      case 'cf_deploy_worker':
        final uri = Uri.parse(
            'https://api.cloudflare.com/client/v4/accounts/${a['account_id']}/workers/scripts/${a['name']}');
        final req = http.MultipartRequest('PUT', uri)
          ..headers['Authorization'] = 'Bearer ${token.trim()}'
          ..files.add(http.MultipartFile.fromString(
            'metadata',
            jsonEncode({
              'main_module': 'worker.js',
              'compatibility_date': '2025-01-01',
            }),
            filename: 'metadata.json',
            contentType: MediaType('application', 'json'),
          ))
          ..files.add(http.MultipartFile.fromString(
            'worker.js',
            a['script'].toString(),
            filename: 'worker.js',
            contentType: MediaType('application', 'javascript'),
          ));
        final res =
            await _client.send(req).timeout(const Duration(seconds: 60));
        final text = await res.stream.bytesToString();
        final j = jsonDecode(text) as Map<String, dynamic>;
        if (j['success'] != true) {
          final errs = (j['errors'] as List?) ?? const [];
          final msg = errs.isNotEmpty
              ? ((errs.first as Map)['message'] ?? 'deploy failed')
              : 'HTTP ${res.statusCode}';
          throw Exception('Cloudflare · $msg');
        }
        return _json({
          'ok': true,
          'worker': a['name'],
          'url': 'https://${a['name']}.<subdomain>.workers.dev',
          'note': 'workers.dev subdomain may need enabling once in the dashboard',
        });

      case 'cf_list_workers':
        final r = await _req('GET', '/accounts/${a['account_id']}/workers/scripts');
        final out = (r['result'] as List).map((x) => {
              'id': x['id'],
              if (x['created_on'] != null) 'created': x['created_on'],
            }).toList();
        return _json({'ok': true, 'workers': out});
    }
    return _json({'error': 'unknown tool $name'});
  }

  String _json(Object o) => jsonEncode(o);
}
