/// Lógica pura: quais produtos do estoque ainda não têm posição no Gôndolas.

class ProdutoSemPosicao {
  const ProdutoSemPosicao({
    required this.codigos,
    required this.nome,
    required this.categoria,
    required this.qtdSistema,
  });

  final List<String> codigos;
  final String nome;
  final String categoria;
  final double qtdSistema;
}

String? normalizarCodigo(String? c) {
  if (c == null) return null;
  final t = c.trim().toUpperCase();
  return t.isEmpty ? null : t;
}

const _comAcento = 'ÁÀÂÃÄÉÈÊËÍÌÎÏÓÒÔÕÖÚÙÛÜÇÑ';
const _semAcento = 'AAAAAEEEEIIIIOOOOOUUUUCN';

String chaveNome(String texto) {
  final sb = StringBuffer();
  for (final r in texto.trim().toUpperCase().runes) {
    final ch = String.fromCharCode(r);
    final i = _comAcento.indexOf(ch);
    sb.write(i >= 0 ? _semAcento[i] : ch);
  }
  return sb.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// [estoque]: linhas de estoque_mestre (codigo, produto, categoria, qtd_sistema).
/// [codigosComPosicao]: códigos presentes em qualquer tabela de endereço.
/// [vinculos]: código → produto_id do cadastro (mapa_produtos*), pode ser vazio.
///
/// Produtos com mais de um código (ex.: 254185 e US254185) formam um grupo: se
/// QUALQUER código do grupo tem posição, o produto tem posição. O grupo é o
/// cadastro quando existe; senão, o mesmo nome (sem acento/caixa).
List<ProdutoSemPosicao> calcularSemPosicao({
  required List<Map<String, dynamic>> estoque,
  required Set<String> codigosComPosicao,
  Map<String, String> vinculos = const {},
}) {
  final grupos = <String, List<Map<String, dynamic>>>{};
  for (final r in estoque) {
    final cod = normalizarCodigo(r['codigo'] as String?);
    if (cod == null) continue;
    final nome = (r['produto'] as String?) ?? '';
    final pid = vinculos[cod];
    final chave = pid != null ? 'id:$pid' : 'nome:${chaveNome(nome)}';
    grupos.putIfAbsent(chave, () => []).add({...r, 'codigo': cod});
  }
  final saida = <ProdutoSemPosicao>[];
  for (final linhas in grupos.values) {
    if (linhas.any((l) => codigosComPosicao.contains(l['codigo']))) continue;
    final base = linhas.first;
    saida.add(ProdutoSemPosicao(
      codigos: [for (final l in linhas) l['codigo'] as String],
      nome: ((base['produto'] as String?) ?? '').trim(),
      categoria: ((base['categoria'] as String?) ?? '').trim(),
      qtdSistema: linhas.fold<double>(
        0,
        (s, l) => s + ((l['qtd_sistema'] as num?)?.toDouble() ?? 0),
      ),
    ));
  }
  saida.sort((a, b) {
    final c = a.categoria.compareTo(b.categoria);
    return c != 0 ? c : a.nome.compareTo(b.nome);
  });
  return saida;
}
