import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sem_posicao.dart';
import 'turso_http.dart';

void main() => runApp(const SemPosicaoApp());

class SemPosicaoApp extends StatelessWidget {
  const SemPosicaoApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Sem Posição',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE87722)),
          useMaterial3: true,
        ),
        home: const ListaPage(),
      );
}

class ListaPage extends StatefulWidget {
  const ListaPage({super.key});

  @override
  State<ListaPage> createState() => _ListaPageState();
}

class _ListaPageState extends State<ListaPage> {
  static const _kUrl = 'turso_db_url';
  static const _kToken = 'turso_db_token';

  List<ProdutoSemPosicao> _todos = [];
  bool _carregando = true;
  bool _soComEstoque = true;
  String? _erro;
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      final url = prefs.getString(_kUrl) ?? '';
      final token = prefs.getString(_kToken) ?? '';
      if (url.isEmpty || token.isEmpty) {
        setState(() {
          _carregando = false;
          _erro = 'Configure a URL e o token do banco (⚙️).';
        });
        return;
      }
      final r = await TursoHttp(url, token).consultar([
        'SELECT codigo, produto, categoria, qtd_sistema FROM estoque_mestre',
        'SELECT DISTINCT produto_codigo AS c FROM estoque_localizado',
        'SELECT DISTINCT produto_codigo AS c FROM gondola_layout',
        'SELECT DISTINCT produto_codigo AS c FROM estante_layout',
        'SELECT DISTINCT produto_codigo AS c FROM galpao_racks',
        "SELECT DISTINCT produto_codigo AS c FROM barracao_enderecos WHERE produto_codigo <> ''",
        'SELECT produto_id, codigo FROM mapa_produtos WHERE codigo IS NOT NULL',
        'SELECT produto_id, codigo FROM mapa_produtos_codigos WHERE codigo IS NOT NULL',
      ]);
      if (r[0] == null) throw Exception('Tabela estoque_mestre não encontrada');
      final posicionados = <String>{};
      for (var i = 1; i <= 5; i++) {
        for (final row in r[i] ?? const []) {
          final c = normalizarCodigo(row['c'] as String?);
          if (c != null) posicionados.add(c);
        }
      }
      final vinculos = <String, String>{};
      for (var i = 6; i <= 7; i++) {
        for (final row in r[i] ?? const []) {
          final c = normalizarCodigo(row['codigo'] as String?);
          final id = row['produto_id']?.toString().trim() ?? '';
          if (c != null && id.isNotEmpty) vinculos[c] = id;
        }
      }
      final lista = calcularSemPosicao(
        estoque: r[0]!,
        codigosComPosicao: posicionados,
        vinculos: vinculos,
      );
      setState(() {
        _todos = lista;
        _carregando = false;
      });
    } catch (e) {
      setState(() {
        _carregando = false;
        _erro = 'Falha ao carregar: $e';
      });
    }
  }

  Future<void> _configurar() async {
    final prefs = await SharedPreferences.getInstance();
    final url = TextEditingController(text: prefs.getString(_kUrl) ?? '');
    final token = TextEditingController(text: prefs.getString(_kToken) ?? '');
    if (!mounted) return;
    final salvar = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Banco Turso'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: url,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'libsql://...turso.io',
            ),
          ),
          TextField(
            controller: token,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Token'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Salvar')),
        ],
      ),
    );
    if (salvar == true) {
      await prefs.setString(_kUrl, url.text.trim());
      await prefs.setString(_kToken, token.text.trim());
      _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = chaveNome(_busca);
    final lista = _todos.where((p) {
      if (_soComEstoque && p.qtdSistema <= 0) return false;
      if (q.isEmpty) return true;
      return chaveNome(p.nome).contains(q) ||
          p.codigos.any((c) => c.contains(q));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sem posição'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _carregar),
          IconButton(icon: const Icon(Icons.settings), onPressed: _configurar),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar produto ou código',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _busca = v),
          ),
        ),
        SwitchListTile(
          dense: true,
          title: const Text('Só com saldo no sistema'),
          value: _soComEstoque,
          onChanged: (v) => setState(() => _soComEstoque = v),
        ),
        if (!_carregando && _erro == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text('${lista.length} produtos sem posição'),
          ),
        Expanded(child: _corpo(lista)),
      ]),
    );
  }

  Widget _corpo(List<ProdutoSemPosicao> lista) {
    if (_carregando) return const Center(child: CircularProgressIndicator());
    if (_erro != null) {
      return Center(
        child: Padding(padding: const EdgeInsets.all(24), child: Text(_erro!, textAlign: TextAlign.center)),
      );
    }
    if (lista.isEmpty) {
      return const Center(child: Text('Tudo com posição! 🎉'));
    }
    return RefreshIndicator(
      onRefresh: _carregar,
      child: ListView.separated(
        itemCount: lista.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final p = lista[i];
          return ListTile(
            title: Text(p.nome),
            subtitle: Text('${p.codigos.join(' + ')} · ${p.categoria}'),
            trailing: Text(
              p.qtdSistema == p.qtdSistema.roundToDouble()
                  ? p.qtdSistema.toStringAsFixed(0)
                  : p.qtdSistema.toStringAsFixed(1),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }
}
