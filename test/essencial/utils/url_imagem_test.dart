import 'package:app/src/essencial/utils/url_imagem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UrlImagem.montarUrlImagem', () {
    test('monta imagem de produto com caminho relativo', () {
      final url = UrlImagem.montarUrlImagem(
        foto: 'produtos/pizza.png',
        baseHost: 'http://192.168.2.113',
      );

      expect(
        url,
        'http://192.168.2.113/sistema/apis_restaurantes/imagens/produtos/pizza.png',
      );
    });

    test('normaliza url completa retornada pela pesquisa de produtos', () {
      final url = UrlImagem.montarUrlImagem(
        foto:
            'https://bigchef.com.br/sistema/apis_restaurantes/imagens/produtos/pizza.png',
        baseHost: 'http://192.168.2.113',
      );

      expect(
        url,
        'http://192.168.2.113/sistema/apis_restaurantes/imagens/produtos/pizza.png',
      );
    });

    test('mantem url absoluta externa quando nao e imagem da API', () {
      final url = UrlImagem.montarUrlImagem(
        foto: 'https://cdn.exemplo.com/produtos/pizza.png',
        baseHost: 'http://192.168.2.113',
      );

      expect(url, 'https://cdn.exemplo.com/produtos/pizza.png');
    });
  });
}
