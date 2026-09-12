import 'dart:convert';
import 'dart:io';
import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:app/src/modulos/autenticacao/modelos/pre_cadastro_modelo.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServicoAutenticacao {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;
  ServicoAutenticacao(this.dio, this.usuarioProvedor);

  Future<bool> entrar(String? usuario, String? senha, {bool permitirSessaoSalva = false}) async {
    if (usuario == null || senha == null || usuario.isEmpty || senha.isEmpty) {
      return false;
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final servidor = (await Apis().getConexao()).servidor;
    final banco = BancoLocal.instancia;

    var campos = {
      "usuario": usuario,
      "senha": senha,
    };

    try {
      final response = await dio.cliente.post(
        'autenticacao/entrar.php',
        options: Options(headers: {
          HttpHeaders.contentTypeHeader: "application/json",
        }),
        data: jsonEncode(campos),
      );

      Map result = response.data;
      bool sucesso = result['sucesso'];
      dynamic dados = result['resultado'];

      if (response.statusCode == 200 && sucesso == true) {
        await prefs.setString(ConfigSharedPreferences.usuario, jsonEncode(dados));
        await banco?.gravar('sessao:$servidor', jsonEncode({
          'id': dados['id'], 'empresa': dados['empresa'], 'autorizada': true,
        }));
        usuarioProvedor.setUsuario(UsuarioModelo.fromMap(dados));
        return sucesso;
      } else {
        if (permitirSessaoSalva) await banco?.gravar('sessao:$servidor', '{"autorizada":false}');
        return false;
      }
    } on DioException catch (erro) {
      if (permitirSessaoSalva && [401, 403].contains(erro.response?.statusCode)) {
        await banco?.gravar('sessao:$servidor', '{"autorizada":false}');
      }
      if (permitirSessaoSalva && CacheConsultas.falhaDeConexao(erro) && banco != null) {
        final salvo = prefs.getString(ConfigSharedPreferences.usuario);
        final autorizacao = await banco.ler('sessao:$servidor');
        if (salvo != null && autorizacao != null) {
          final dados = jsonDecode(salvo) as Map<String, dynamic>;
          final sessao = jsonDecode(autorizacao) as Map<String, dynamic>;
          if (sessao['autorizada'] == true && sessao['id'] == dados['id'] &&
              sessao['empresa'] == dados['empresa'] && dados['email'] == usuario) {
            usuarioProvedor.setUsuario(UsuarioModelo.fromMap(dados));
            return true;
          }
        }
      }
      return false;
    }
  }

  Future<List<dynamic>> preCadastro(PreCadastroModelo formulario) async {
    var url = 'autenticacao/pre_cadastro.php';

    final data = {
      ...formulario.toMap(),
    };

    final response = await dio.cliente.post(url, data: jsonEncode(data));

    Map result = response.data;
    bool sucesso = result['sucesso'];
    dynamic mensagem = result['mensagem'];

    if (response.statusCode == 200) {
      return [sucesso, mensagem];
    } else {
      return [false, 'Erro ao tentar inserir'];
    }
  }

  Future<({bool sucesso, String mensagem})> excluirConta() async {
    var id = usuarioProvedor.usuario!.id;
    var empresa = usuarioProvedor.usuario!.empresa;

    var url = 'autenticacao/excluir_conta.php';

    var campos = {
      "id_cliente": id,
      "empresa": empresa,
    };

    final response = await dio.cliente.post(
      url,
      data: jsonEncode(campos),
    );

    Map result = response.data;
    bool sucesso = result['sucesso'];
    String mensagem = result['mensagem'];

    if (response.statusCode == 200 && sucesso == true) {
      return (sucesso: sucesso, mensagem: mensagem);
    } else {
      return (sucesso: false, mensagem: mensagem);
    }
  }
}
