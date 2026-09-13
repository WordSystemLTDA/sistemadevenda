import 'dart:convert';

import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import 'modelo_indicadores.dart';

class FalhaIndicadores implements Exception {
  const FalhaIndicadores(this.mensagem);
  final String mensagem;
  @override
  String toString() => mensagem;
}

class ServicoIndicadores {
  ServicoIndicadores(this.dio, this.usuarios,
      {this.banco, Future<String> Function()? servidor})
      : obterServidor =
            servidor ?? (() async => (await Apis().getConexao()).servidor);
  final DioCliente dio;
  final UsuarioProvedor usuarios;
  final BancoLocal? banco;
  final Future<String> Function() obterServidor;

  Future<ModeloIndicadores> consultar(DateTime inicio, DateTime fim,
      {CancelToken? cancelToken}) async {
    final usuario = usuarios.usuario;
    if (!podeVerIndicadores(usuario)) {
      throw const FalhaIndicadores('Acesso restrito aos administradores.');
    }
    final servidor = await obterServidor();
    final chave =
        'indicadores:${BancoLocal.escopo(servidor, usuario!.empresa ?? '', usuario.id ?? '')}';
    final armazenamento = banco ?? BancoLocal.instancia;
    final formato = DateFormat('yyyy-MM-dd');
    final de = formato.format(inicio);
    final ate = formato.format(fim);
    Future<void> conferirSessao() async {
      if (usuarios.usuario != usuario || servidor != await obterServidor()) {
        throw const FalhaIndicadores(
            'A conexão ou o usuário mudou. Consulte novamente.');
      }
      if (cancelToken?.isCancelled == true) throw cancelToken!.cancelError!;
    }

    try {
      final resposta = await dio.cliente.post('indicadores/listar.php',
          data: {
            'id_usuario': usuario.id,
            'empresa': usuario.empresa,
            'usuario': usuario.email,
            'senha': usuario.senha,
            'inicio': de,
            'fim': ate
          },
          cancelToken: cancelToken,
          options: Options(
              extra: {'semCache': true, 'servidorFixo': servidor},
              sendTimeout: const Duration(seconds: 8),
              receiveTimeout: const Duration(seconds: 12)));
      await conferirSessao();
      final body =
          resposta.data is String ? jsonDecode(resposta.data) : resposta.data;
      if (body is! Map ||
          body['sucesso'] != true ||
          body['resultado'] is! Map) {
        throw const FalhaIndicadores(
            'Atualize a API do servidor para consultar os indicadores.');
      }
      final dados = Map<String, dynamic>.from(body['resultado']);
      final modelo = ModeloIndicadores.fromMap(dados);
      if (dados['inicio'] != de || dados['fim'] != ate) {
        throw const FalhaIndicadores(
            'O servidor retornou outro período. Tente novamente.');
      }
      try {
        // Guarda somente o ultimo periodo por servidor/empresa/usuario, sem credenciais.
        await armazenamento?.gravar(chave, jsonEncode(dados));
      } catch (_) {
        // Falha de armazenamento nao impede a consulta online.
      }
      await conferirSessao();
      return modelo;
    } on DioException catch (erro) {
      await conferirSessao();
      if (erro.response?.statusCode == 401 ||
          erro.response?.statusCode == 403) {
        try {
          await armazenamento?.gravar(chave, '');
        } catch (_) {}
        throw FalhaIndicadores(erro.response?.statusCode == 401
            ? 'Sessão inválida. Entre novamente.'
            : 'Acesso restrito aos administradores.');
      }
      if (erro.response?.statusCode == 404) {
        throw const FalhaIndicadores(
            'Atualize a API do servidor para consultar os indicadores.');
      }
      if (CacheConsultas.falhaDeConexao(erro)) {
        ModeloIndicadores? salvo;
        try {
          final texto = await armazenamento?.ler(chave);
          if (texto != null && texto.isNotEmpty) {
            final dados = jsonDecode(texto) as Map<String, dynamic>;
            if (dados['inicio'] == de && dados['fim'] == ate) {
              final modelo = ModeloIndicadores.fromMap(dados, offline: true);
              final idade = DateTime.now().difference(modelo.atualizadoEm);
              if (!idade.isNegative && idade < const Duration(hours: 24)) {
                salvo = modelo;
              }
            }
          }
        } catch (_) {}
        await conferirSessao();
        if (salvo != null) return salvo;
        throw const FalhaIndicadores(
            'Servidor indisponível. Não há consulta recente para este período.');
      }
      throw const FalhaIndicadores(
          'Não foi possível atualizar os indicadores. Tente novamente.');
    }
  }
}
