import 'dart:convert';
import 'dart:io';
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/atendimentos_locais.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:app/src/essencial/utils/recursos_atendimento_unicos.dart';
import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:app/src/modulos/mesas/servicos/servico_mesas.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  for (final tipo in ['comanda', 'mesa']) {
    test('$tipo: resposta Online e cache offline mostram uma entrada por nome',
        () async {
      SharedPreferences.setMockInitialValues({});
      final pasta =
          await Directory.systemTemp.createTemp('recursos-repetidos-');
      final banco = await BancoLocal.abrir(
          factory: databaseFactoryFfi, path: '${pasta.path}/db');
      BancoLocal.instancia = banco;
      final api = DioCliente(servidor: 'https://fixture/api41/');
      final usuario = UsuarioProvedor()
        ..setUsuario(UsuarioModelo(id: '1', empresa: '2'));
      final cache = api.cache!;
      cache.escopo = BancoLocal.escopo('https://fixture/api41/', '2', '1');
      cache.servidor = 'https://fixture/api41/';
      cache.empresa = '2';
      var online = true;
      final campo = tipo == 'mesa' ? 'mesas' : 'comandas';
      final ocupado = tipo == 'mesa' ? 'mesaOcupada' : 'comandaOcupada';
      final recursos = [
        for (final id in ['11', '316'])
          {
            'id': id,
            'nome': tipo == 'mesa' ? 'Mesa: 4' : 'Comanda: 1',
            'codigo': id,
            'ativo': 'Sim',
            ocupado: false,
          }
      ];
      api.cliente.interceptors.add(InterceptorsWrapper(onRequest: (op, h) {
        if (!online) {
          h.reject(
              DioException(
                  requestOptions: op, type: DioExceptionType.connectionError),
              true);
        } else {
          h.resolve(
              Response(
                  requestOptions: op,
                  statusCode: 200,
                  data: op.path.endsWith('listar_lista.php')
                      ? recursos
                      : [
                          {'titulo': 'Ocupadas', campo: []},
                          {'titulo': 'Livres', campo: recursos}
                        ]),
              true);
        }
      }));
      Future<List<String>> consultar() async {
        if (tipo == 'mesa') {
          final grupos = await ServicoMesas(api, usuario).listar('');
          return grupos
              .expand((g) => g.mesas ?? [])
              .map((r) => r.id as String)
              .toList();
        }
        final grupos = await ServicoComandas(api, usuario).listar('');
        return grupos
            .expand((g) => g.comandas ?? [])
            .map((r) => r.id as String)
            .toList();
      }

      try {
        expect(await consultar(), ['11']);
        Future<List<String>> consultarCadastro() async => tipo == 'mesa'
            ? (await ServicoMesas(api, usuario).listarLista(''))
                .map((r) => r.id)
                .toList()
            : (await ServicoComandas(api, usuario).listarLista(''))
                .map((r) => r.id)
                .toList();
        expect(await consultarCadastro(), ['11']);
        final request = RequestOptions(
            path: '$campo/listar.php',
            queryParameters: {'empresa': '2', 'pesquisa': ''});
        final salvo =
            await banco.consulta(cache.escopo, CacheConsultas.chave(request));
        expect(jsonDecode(salvo!['valor'] as String).last[campo], hasLength(2));
        online = false;
        expect(await consultar(), ['11']);
        expect(await consultarCadastro(), ['11']);

        // Uma abertura local no alias precisa ocupar o nome, mantendo o ID
        // escolhido antes da correcao e a dependencia da sincronizacao.
        final locais = AtendimentosLocais(banco, cache.escopo);
        final idLocal = await locais.abrir({
          'tipo': tipo,
          'id_mesa': tipo == 'mesa' ? '316' : '0',
          'id_comanda': tipo == 'comanda' ? '316' : '0',
          'detalhe': {
            'nome': recursos.last['nome'],
            'codigo': '316',
            'idCliente': '0',
            'nomeCliente': '',
            'dataAbertura': '2026-10-09T21:34:00',
          }
        }, 'fixture');
        final projetada = await locais.projetarLista(
            jsonDecode(salvo['valor'] as String) as List, tipo, '');
        final unicos = recursosAtendimentoUnicos(projetada, tipo);
        final ocupada = (unicos.first[campo] as List).single as Map;
        expect(ocupada['id'], '316');
        expect(ocupada['idComandaPedido'], idLocal);
        expect(ocupada[ocupado], true);
        expect(unicos.last[campo], isEmpty);
      } finally {
        api.cliente.close(force: true);
        usuario.dispose();
        BancoLocal.instancia = null;
        await banco.db.close();
        await pasta.delete(recursive: true);
      }
    });
  }
}
