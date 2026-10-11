import 'package:flutter_test/flutter_test.dart';
import 'package:sem_posicao/sem_posicao.dart';

void main() {
  test('produto com algum código posicionado não entra; sem posição entra', () {
    final r = calcularSemPosicao(
      estoque: [
        {'codigo': '254185', 'produto': 'Herbicida X', 'categoria': 'Defensivos', 'qtd_sistema': 171},
        {'codigo': 'US254185', 'produto': 'HERBICIDA X', 'categoria': 'Defensivos', 'qtd_sistema': 388},
        {'codigo': '1', 'produto': 'Óleo Y', 'categoria': 'Lubrificantes', 'qtd_sistema': 5},
        {'codigo': '2', 'produto': 'Bota', 'categoria': 'Calçados', 'qtd_sistema': 2},
        {'codigo': '3', 'produto': 'Bota Preta', 'categoria': 'Calçados', 'qtd_sistema': 4},
      ],
      codigosComPosicao: {'US254185'},
      vinculos: {'2': 'a'},
    );
    expect(r.map((p) => p.nome), ['Bota', 'Bota Preta', 'Óleo Y']);
    expect(r.first.codigos, ['2']);
  });
}
