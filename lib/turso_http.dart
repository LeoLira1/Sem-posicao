import 'dart:convert';

import 'package:http/http.dart' as http;

/// Cliente mínimo (somente leitura) da API HTTP do Turso/libSQL.
class TursoHttp {
  TursoHttp(String url, this.token, {http.Client? client})
      : base = _paraHttps(url),
        _client = client ?? http.Client();

  final String base;
  final String token;
  final http.Client _client;

  static String _paraHttps(String url) {
    var u = url.trim();
    u = u.replaceFirst(RegExp(r'^libsql://'), 'https://');
    if (!u.startsWith('http')) u = 'https://$u';
    return u.replaceAll(RegExp(r'/+$'), '');
  }

  /// Executa [sqls] numa só chamada. Uma consulta que falha (ex.: tabela
  /// inexistente) vira `null` na posição correspondente, sem derrubar as outras.
  Future<List<List<Map<String, dynamic>>?>> consultar(List<String> sqls) async {
    final corpo = jsonEncode({
      'requests': [
        for (final s in sqls)
          {
            'type': 'execute',
            'stmt': {'sql': s},
          },
        {'type': 'close'},
      ],
    });
    final resp = await _client
        .post(
          Uri.parse('$base/v2/pipeline'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: corpo,
        )
        .timeout(const Duration(seconds: 40));
    if (resp.statusCode != 200) {
      throw Exception('Turso respondeu ${resp.statusCode}');
    }
    final json = jsonDecode(utf8.decode(resp.bodyBytes)) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>;
    return [
      for (var i = 0; i < sqls.length; i++) _linhas(results[i] as Map<String, dynamic>),
    ];
  }

  static List<Map<String, dynamic>>? _linhas(Map<String, dynamic> r) {
    if (r['type'] != 'ok') return null;
    final res = (r['response'] as Map<String, dynamic>)['result'] as Map<String, dynamic>;
    final cols = [for (final c in res['cols'] as List<dynamic>) (c as Map)['name'] as String];
    return [
      for (final row in res['rows'] as List<dynamic>)
        {
          for (var i = 0; i < cols.length; i++)
            cols[i]: _valor((row as List<dynamic>)[i] as Map<String, dynamic>),
        },
    ];
  }

  static dynamic _valor(Map<String, dynamic> v) {
    switch (v['type']) {
      case 'integer':
        return int.tryParse(v['value'].toString());
      case 'float':
        return (v['value'] as num).toDouble();
      case 'text':
        return v['value'] as String;
      default:
        return null;
    }
  }
}
