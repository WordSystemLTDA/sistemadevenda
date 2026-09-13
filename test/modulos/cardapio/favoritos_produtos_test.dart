import 'dart:async';

import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/utils/normalizar_busca.dart';
import 'package:app/src/modulos/cardapio/provedores/favoritos_produtos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UsuarioProvedor usuarios;
  late FavoritosProdutos favoritos;
  var servidor = 'http://restaurante-a/api1/';

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    servidor = 'http://restaurante-a/api1/';
    usuarios = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '32'));
    favoritos = FavoritosProdutos(usuarios, servidor: () async => servidor);
  });
  tearDown(() {
    favoritos.dispose();
    usuarios.dispose();
  });

  test('busca ignora acentos, caixa e caracteres combinados', () {
    expect(normalizarBusca('  AÇAÍ  '), 'acai');
    expect(normalizarBusca('A\u0301gua   COM GÁS'), 'agua com gas');
    expect(normalizarBusca('PÃO de Queijo'), 'pao de queijo');
  });

  test('favoritos persistem somente IDs e funcionam sem acessar a rede',
      () async {
    await favoritos.carregar();
    expect(await favoritos.alternar('101'), isTrue);
    expect(await favoritos.alternar('202'), isTrue);
    final outraTela =
        FavoritosProdutos(usuarios, servidor: () async => servidor);
    addTearDown(outraTela.dispose);
    await outraTela.carregar();
    expect(outraTela.ids, {'101', '202'});
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys(), hasLength(1));
    expect(prefs.getStringList(prefs.getKeys().single), ['101', '202']);
    expect(await outraTela.alternar('101'), isTrue);
    await favoritos.carregar();
    expect(favoritos.ids, {'202'});
  });

  test('toques rapidos nao apagam favoritos nem duplicam IDs', () async {
    await favoritos.carregar();
    final primeiro = favoritos.alternar('1');
    final segundo = favoritos.alternar('2');
    final terceiro = favoritos.alternar('1');
    expect(await primeiro, isTrue);
    expect(await segundo, isTrue);
    expect(await terceiro, isTrue);
    expect(favoritos.ids, {'2'});
  });

  test('outra tela nao sobrescreve preferencia salva pela anterior', () async {
    await favoritos.carregar();
    final outraTela =
        FavoritosProdutos(usuarios, servidor: () async => servidor);
    addTearDown(outraTela.dispose);
    await outraTela.carregar();
    await favoritos.alternar('101');
    await outraTela.alternar('202');
    await favoritos.carregar();
    expect(favoritos.ids, {'101', '202'});
  });

  test('isola preferencias por servidor, empresa e usuario', () async {
    await favoritos.carregar();
    await favoritos.alternar('101');
    servidor = 'http://restaurante-b/api1/';
    await favoritos.carregar();
    expect(favoritos.ids, isEmpty);
    servidor = 'http://restaurante-a/api1/';
    usuarios.setUsuario(UsuarioModelo(id: '2', empresa: '32'));
    expect(favoritos.ids, isEmpty);
    await favoritos.carregar();
    expect(favoritos.ids, isEmpty);
    usuarios.setUsuario(UsuarioModelo(id: '1', empresa: '99'));
    await favoritos.carregar();
    expect(favoritos.ids, isEmpty);
    usuarios.setUsuario(UsuarioModelo(id: '1', empresa: '32'));
    await favoritos.carregar();
    expect(favoritos.ids, {'101'});
  });

  test('troca de servidor durante uso recusa salvar no escopo antigo',
      () async {
    await favoritos.carregar();
    servidor = 'http://restaurante-b/api1/';
    expect(await favoritos.alternar('101'), isFalse);
    expect(favoritos.disponivel, isFalse);
    expect(favoritos.ids, isEmpty);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('logout invalida gravacao pendente e nao exibe favoritos anteriores',
      () async {
    await favoritos.carregar();
    final salvando = favoritos.alternar('1');
    usuarios.setUsuario(null);
    expect(await salvando, isFalse);
    await favoritos.carregar();
    expect(favoritos.ids, isEmpty);
    expect(favoritos.disponivel, isFalse);
  });

  test('armazenamento invalido mostra falha sem encerrar aplicativo', () async {
    final chave =
        'favoritos_produtos:v1:${BancoLocal.escopo(servidor, '32', '1')}';
    SharedPreferences.setMockInitialValues({chave: 'formato-invalido'});
    await favoritos.carregar();
    expect(favoritos.erro, isNotNull);
    expect(favoritos.ids, isEmpty);
    expect(favoritos.disponivel, isFalse);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(chave);
    await favoritos.carregar();
    expect(favoritos.disponivel, isTrue);
  });

  test('descarte durante carregamento nao notifica widget desmontado',
      () async {
    final resposta = Completer<String>();
    final temporario =
        FavoritosProdutos(usuarios, servidor: () => resposta.future);
    final carregando = temporario.carregar();
    temporario.dispose();
    resposta.complete(servidor);
    await carregando;
    expect(temporario.disponivel, isFalse);
  });
}
