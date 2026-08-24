import 'dart:convert';

import 'package:http/http.dart' as http;

/// Direct GitHub REST integration — the agent operates the user's account:
/// repos, file pushes, issues, PRs and Actions workflows.
class GitHubService {
  String token = '';
  bool get connected => token.trim().isNotEmpty;

  static const toolDefs = <Map<String, Object>>[
    {
      'name': 'gh_list_repos',
      'description':
          'List the user\'s GitHub repositories (most recently updated first).',
      'parameters': {'type': 'object', 'properties': <String, dynamic>{}},
    },
    {
      'name': 'gh_create_repo',
      'description':
          'Create a new GitHub repository under the user\'s account.',
      'parameters': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'private': {
            'type': 'boolean',
            'description': 'Default true — keep it private unless asked.'
          },
          'description': {'type': 'string'},
        },
        'required': ['name'],
      },
    },
    {
      'name': 'gh_read_file',
      'description': 'Read one file from a repository.',
      'parameters': {
        'type': 'object',
        'properties': {
          'repo': {
            'type': 'string',
            'description': 'owner/name, e.g. mamad7202202/dragon-agent'
          },
          'path': {'type': 'string'},
          'ref': {'type': 'string', 'description': 'Branch or tag. Optional.'},
        },
        'required': ['repo', 'path'],
      },
    },
    {
      'name': 'gh_push_file',
      'description':
          'Create or update a single file in a repository (commits directly).',
      'parameters': {
        'type': 'object',
        'properties': {
          'repo': {'type': 'string'},
          'path': {'type': 'string'},
          'content': {'type': 'string', 'description': 'Full file content.'},
          'message': {'type': 'string', 'description': 'Commit message.'},
          'branch': {'type': 'string', 'description': 'Optional branch.'},
        },
        'required': ['repo', 'path', 'content', 'message'],
      },
    },
    {
      'name': 'gh_push_files',
      'description':
          'Write multiple files in one commit — the preferred way to put code '
              'into a repository (e.g. a whole project or library set).',
      'parameters': {
        'type': 'object',
        'properties': {
          'repo': {'type': 'string'},
          'files': {
            'type': 'object',
            'description': 'Map of path → full file content.',
            'additionalProperties': {'type': 'string'},
          },
          'message': {'type': 'string'},
          'branch': {'type': 'string', 'description': 'Defaults to the default branch.'},
        },
        'required': ['repo', 'files', 'message'],
      },
    },
    {
      'name': 'gh_create_issue',
      'description': 'Open an issue on a repository.',
      'parameters': {
        'type': 'object',
        'properties': {
          'repo': {'type': 'string'},
          'title': {'type': 'string'},
          'body': {'type': 'string'},
        },
        'required': ['repo', 'title'],
      },
    },
    {
      'name': 'gh_create_pull_request',
      'description': 'Open a pull request from head branch into base branch.',
      'parameters': {
        'type': 'object',
        'properties': {
          'repo': {'type': 'string'},
          'title': {'type': 'string'},
          'head': {'type': 'string'},
          'base': {'type': 'string'},
          'body': {'type': 'string'},
        },
        'required': ['repo', 'title', 'head', 'base'],
      },
    },
    {
      'name': 'gh_list_workflows',
      'description': 'List GitHub Actions workflows of a repository.',
      'parameters': {
        'type': 'object',
        'properties': {
          'repo': {'type': 'string'},
        },
        'required': ['repo'],
      },
    },
    {
      'name': 'gh_trigger_workflow',
      'description':
          'Dispatch a GitHub Actions workflow — use it to build, test or '
              'release code on GitHub\'s infrastructure.',
      'parameters': {
        'type': 'object',
        'properties': {
          'repo': {'type': 'string'},
          'workflow': {
            'type': 'string',
            'description': 'Workflow file name, e.g. build.yml, or numeric id.'
          },
          'ref': {
            'type': 'string',
            'description': 'Branch or tag to run against, e.g. main.'
          },
          'inputs': {
            'type': 'object',
            'description': 'Workflow inputs. Optional.',
            'additionalProperties': {'type': 'string'},
          },
        },
        'required': ['repo', 'workflow', 'ref'],
      },
    },
    {
      'name': 'gh_list_runs',
      'description': 'List recent Actions runs with their status.',
      'parameters': {
        'type': 'object',
        'properties': {
          'repo': {'type': 'string'},
        },
        'required': ['repo'],
      },
    },
  ];

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${token.trim()}',
        'Accept': 'application/vnd.github+json',
        'Content-Type': 'application/json',
      };

  final http.Client _client = http.Client();

  Future<dynamic> _req(String method, String path, {Object? body}) async {
    final uri = Uri.parse('https://api.github.com$path');
    final req = http.Request(method, uri)..headers.addAll(_headers);
    if (body != null) req.body = jsonEncode(body);
    final res = await _client.send(req).timeout(const Duration(seconds: 30));
    final text = await res.stream.bytesToString();
    if (res.statusCode >= 300) {
      String msg = text;
      try {
        final j = jsonDecode(text) as Map<String, dynamic>;
        msg = (j['message'] as String?) ?? text;
      } catch (_) {}
      throw Exception('GitHub HTTP ${res.statusCode} · ${_clip(msg, 200)}');
    }
    if (text.isEmpty) return null;
    return jsonDecode(text);
  }

  /// Handles a gh_* tool call; returns a compact JSON string for the model.
  Future<String> handleTool(String name, Map<String, dynamic> a) async {
    switch (name) {
      case 'gh_list_repos':
        final repos = await _req('GET', '/user/repos?per_page=30&sort=updated');
        final out = (repos as List).map((r) => {
              'name': r['full_name'],
              'private': r['private'],
              'url': r['html_url'],
            }).toList();
        return _json({'ok': true, 'repos': out});

      case 'gh_create_repo':
        final r = await _req('POST', '/user/repos', body: {
          'name': a['name'],
          'private': a['private'] ?? true,
          if (a['description'] != null) 'description': a['description'],
          'auto_init': true,
        });
        return _json({
          'ok': true,
          'full_name': r['full_name'],
          'url': r['html_url'],
          'default_branch': r['default_branch'],
        });

      case 'gh_read_file':
        final ref = a['ref'] == null ? '' : '?ref=${a['ref']}';
        final r = await _req(
            'GET', '/repos/${a['repo']}/contents/${_enc(a['path'])}$ref');
        final encoding = r['encoding'];
        if (encoding == 'base64') {
          final bytes =
              base64Decode((r['content'] as String).replaceAll('\n', ''));
          return _json({
            'ok': true,
            'path': r['path'],
            'content': _clip(utf8.decode(bytes, allowMalformed: true), 8000),
          });
        }
        return _json({'ok': true, 'path': r['path'], 'url': r['download_url']});

      case 'gh_push_file':
        String? sha;
        try {
          final existing = await _req('GET',
              '/repos/${a['repo']}/contents/${_enc(a['path'])}${a['branch'] == null ? '' : '?ref=${a['branch']}'}');
          sha = existing?['sha'] as String?;
        } catch (_) {}
        final r = await _req('PUT',
            '/repos/${a['repo']}/contents/${_enc(a['path'])}',
            body: {
              'message': a['message'] ?? 'update ${a['path']}',
              'content': base64Encode(utf8.encode(a['content'] as String)),
              if (a['branch'] != null) 'branch': a['branch'],
              if (sha != null) 'sha': sha,
            });
        return _json({
          'ok': true,
          'path': (r['content'] as Map)['path'],
          'commit': (r['commit'] as Map)['sha'],
        });

      case 'gh_push_files':
        return _pushFiles(a);

      case 'gh_create_issue':
        final r = await _req('POST', '/repos/${a['repo']}/issues', body: {
          'title': a['title'],
          if (a['body'] != null) 'body': a['body'],
        });
        return _json({'ok': true, 'number': r['number'], 'url': r['html_url']});

      case 'gh_create_pull_request':
        final r = await _req('POST', '/repos/${a['repo']}/pulls', body: {
          'title': a['title'],
          'head': a['head'],
          'base': a['base'],
          if (a['body'] != null) 'body': a['body'],
        });
        return _json({'ok': true, 'number': r['number'], 'url': r['html_url']});

      case 'gh_list_workflows':
        final r = await _req('GET', '/repos/${a['repo']}/actions/workflows');
        final out = (r['workflows'] as List).map((w) => {
              'id': w['id'],
              'name': w['name'],
              'path': w['path'],
              'state': w['state'],
            }).toList();
        return _json({'ok': true, 'workflows': out});

      case 'gh_trigger_workflow':
        await _req(
          'POST',
          '/repos/${a['repo']}/actions/workflows/${a['workflow']}/dispatches',
          body: {
            'ref': a['ref'],
            if (a['inputs'] != null) 'inputs': a['inputs'],
          },
        );
        return _json({
          'ok': true,
          'dispatched': a['workflow'],
          'note': 'run started — check gh_list_runs in a moment'
        });

      case 'gh_list_runs':
        final r = await _req(
            'GET', '/repos/${a['repo']}/actions/runs?per_page=6');
        final out = (r['workflow_runs'] as List).map((w) => {
              'name': w['name'],
              'status': w['status'],
              'conclusion': w['conclusion'],
              'branch': w['head_branch'],
              'url': w['html_url'],
            }).toList();
        return _json({'ok': true, 'runs': out});
    }
    return _json({'error': 'unknown tool $name'});
  }

  Future<String> _pushFiles(Map<String, dynamic> a) async {
    final repo = a['repo'] as String;
    final branch = a['branch'] as String?;
    final files = (a['files'] as Map).cast<String, dynamic>();
    if (files.isEmpty) return _json({'ok': false, 'error': 'no files'});

    // resolve branch head
    String headSha;
    String baseTree;
    String targetBranch;
    if (branch != null && branch.isNotEmpty) {
      final ref = await _req('GET', '/repos/$repo/git/ref/heads/$branch');
      headSha = ref['object']['sha'] as String;
      targetBranch = branch;
    } else {
      final repoInfo = await _req('GET', '/repos/$repo');
      targetBranch = repoInfo['default_branch'] as String;
      final ref =
          await _req('GET', '/repos/$repo/git/ref/heads/$targetBranch');
      headSha = ref['object']['sha'] as String;
    }
    final commit =
        await _req('GET', '/repos/$repo/git/commits/$headSha');
    baseTree = commit['tree']['sha'] as String;

    // create blobs
    final tree = <Map<String, dynamic>>[];
    for (final entry in files.entries) {
      final blob = await _req('POST', '/repos/$repo/git/blobs', body: {
        'content': base64Encode(utf8.encode(entry.value.toString())),
        'encoding': 'base64',
      });
      tree.add({
        'path': entry.key,
        'mode': '100644',
        'type': 'blob',
        'sha': blob['sha'],
      });
    }

    // tree → commit → update ref
    final newTree = await _req('POST', '/repos/$repo/git/trees',
        body: {'base_tree': baseTree, 'tree': tree});
    final newCommit = await _req('POST', '/repos/$repo/git/commits', body: {
      'message': a['message'] ?? 'update ${files.length} files',
      'tree': newTree['sha'],
      'parents': [headSha],
    });
    await _req('PATCH', '/repos/$repo/git/refs/heads/$targetBranch',
        body: {'sha': newCommit['sha']});

    return _json({
      'ok': true,
      'branch': targetBranch,
      'files': files.keys.toList(),
      'commit': newCommit['sha'],
    });
  }

  String _enc(String path) => Uri.encodeComponent(path);

  String _json(Object o) => _clip(jsonEncode(o), 6000);

  String _clip(String s, int n) => s.length <= n ? s : '${s.substring(0, n)}…';
}
