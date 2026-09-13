import 'dart:convert';

import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AlvoTransferencia {
  final String id, atendimento, nome, tipo, versao, motivo, total;
  final bool livre;
  const AlvoTransferencia(
      {required this.id,
      required this.atendimento,
      required this.nome,
      required this.tipo,
      this.versao = '',
      this.motivo = '',
      this.total = '0',
      this.livre = false});

  bool get podeArrastar =>
      !livre && motivo.isEmpty && (int.tryParse(atendimento) ?? 0) > 0;

  factory AlvoTransferencia.fromMap(Map dados) => AlvoTransferencia(
      id: dados['id'].toString(),
      atendimento: dados['atendimento'].toString(),
      nome: dados['nome'].toString(),
      tipo: dados['tipo'].toString(),
      versao: dados['versao']?.toString() ?? '',
      motivo: dados['motivo']?.toString() ?? '',
      total: dados['total']?.toString() ?? '0',
      livre: dados['livre'] == true);

  Map<String, dynamic> toMap() => {
        'id': id,
        'atendimento': atendimento,
        'nome': nome,
        'tipo': tipo,
        'versao': versao,
        'motivo': motivo,
        'total': total,
        'livre': livre
      };
}

class TransferenciaPendente {
  final AlvoTransferencia origem, destino;
  final Map<String, dynamic> entrada;
  const TransferenciaPendente(this.origem, this.destino, this.entrada);
  Map<String, dynamic> toMap() => {
        'origem': origem.toMap(),
        'destino': destino.toMap(),
        'entrada': entrada
      };
  factory TransferenciaPendente.fromMap(Map dados) => TransferenciaPendente(
      AlvoTransferencia.fromMap(dados['origem']),
      AlvoTransferencia.fromMap(dados['destino']),
      Map<String, dynamic>.from(dados['entrada']));
}

class FalhaTransferencia implements Exception {
  final String mensagem;
  final bool pendente;
  const FalhaTransferencia(this.mensagem, {this.pendente = false});
  @override
  String toString() => mensagem;
}

class ServicoTransferencias {
  final DioCliente api;
  final UsuarioProvedor usuario;
  String _servidor = '', _empresa = '', _usuario = '', _escopo = '';
  bool _enviando = false;
  ServicoTransferencias(this.api, this.usuario);

  bool get mostrarValores =>
      usuario.usuario?.configuracoes?.habilitarVerValorTotalNoApp == 'Sim';
  String get _chave => 'transferencia_pendente:$_escopo';
  Options get _opcoes => Options(
      extra: {'semCache': true, 'servidorFixo': _servidor},
      receiveTimeout: const Duration(seconds: 12),
      sendTimeout: const Duration(seconds: 12));
  Map<String, dynamic> get _identificacao =>
      {'empresa': _empresa, 'id_usuario': _usuario};

  Future<void> iniciar() async {
    _empresa = usuario.usuario?.empresa ?? '';
    _usuario = usuario.usuario?.id ?? '';
    if (_empresa.isEmpty || _usuario.isEmpty) {
      throw const FalhaTransferencia('Entre novamente no aplicativo.');
    }
    _servidor = (await Apis().getConexao()).servidor;
    _escopo = BancoLocal.escopo(_servidor, _empresa, _usuario);
  }

  Future<void> _gravar(String? valor) async {
    final banco = BancoLocal.instancia;
    if (banco != null) {
      await banco.gravar(_chave, valor ?? 'null');
    } else {
      final prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString(_chave, valor ?? 'null')) {
        throw const FalhaTransferencia(
            'Nao foi possivel salvar a transferencia no aparelho.');
      }
    }
  }

  Future<TransferenciaPendente?> pendente() async {
    final banco = BancoLocal.instancia;
    final valor = banco != null
        ? await banco.ler(_chave)
        : (await SharedPreferences.getInstance()).getString(_chave);
    final dados = jsonDecode(valor ?? 'null');
    return dados == null ? null : TransferenciaPendente.fromMap(dados);
  }

  Future<Map> _consultar(String rota, Map<String, dynamic> parametros) async {
    try {
      final resposta = await api.cliente.get(rota,
          queryParameters: {..._identificacao, ...parametros},
          options: _opcoes);
      if (resposta.data is! Map ||
          resposta.data['sucesso'] != true ||
          resposta.data['protocolo'] != 1) {
        throw const FalhaTransferencia(
            'Atualize a API e o banco de dados do servidor para usar transferencias.');
      }
      return resposta.data as Map;
    } on DioException {
      throw const FalhaTransferencia(
          'Nao foi possivel consultar o servidor. Confira a conexao e a atualizacao da API e do banco.');
    }
  }

  Future<List<AlvoTransferencia>> listar(String tipo) async {
    final dados =
        await _consultar('transferencias/consultar.php', {'tipo': tipo});
    return (dados['recursos'] as List)
        .map((e) => AlvoTransferencia.fromMap(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> historico(AlvoTransferencia alvo,
      {String? antes}) async {
    final dados = await _consultar('transferencias/historico.php', {
      'tipo': alvo.tipo,
      'recurso': alvo.id,
      if (antes != null) 'antes': antes
    });
    return List<Map<String, dynamic>>.from(dados['historico']);
  }

  Future<void> validarPendencias(
      AlvoTransferencia origem, AlvoTransferencia destino) async {
    final banco = BancoLocal.instancia;
    if (banco != null) {
      // Inclui pedidos aceitos com impressao ainda pendente, sem descartar nada.
      final operacoes = await banco.operacoes(_escopo);
      for (final op in operacoes) {
        final dados = jsonDecode(op['dados'] as String) as Map;
        if ([origem.atendimento, destino.atendimento]
                .contains(op['atendimento']) ||
            [origem.id, destino.id]
                .contains(dados['id_${origem.tipo}']?.toString())) {
          throw const FalhaTransferencia(
              'Sincronize os pedidos e as impressoes destes atendimentos antes de transferir.');
        }
      }
    }
    if (await ArmazenamentoCarrinhos.instancia.temRascunhoDeAtendimentos(
        _empresa, [origem.atendimento, destino.atendimento])) {
      throw const FalhaTransferencia(
          'Ha produtos no carrinho destes atendimentos. Envie ou remova os rascunhos antes de transferir.');
    }
  }

  Future<void> confirmar(
      AlvoTransferencia origem, AlvoTransferencia destino) async {
    if (_enviando) return;
    _enviando = true;
    try {
      if (await pendente() != null) {
        throw const FalhaTransferencia(
            'Verifique primeiro a transferencia pendente.',
            pendente: true);
      }
      await validarPendencias(origem, destino);
      final operacao = TransferenciaPendente(origem, destino, {
        ..._identificacao,
        'acao': 'transferencia',
        'id_operacao': BancoLocal.novoId(),
        'dados': {
          'tipo': origem.tipo,
          'origem': origem.id,
          'destino': destino.id,
          'versao_origem': origem.versao,
          'versao_destino': destino.versao
        },
      });
      // Persistencia antes da rede permite recuperar a mesma operacao apos uma queda.
      await _gravar(jsonEncode(operacao.toMap()));
      await _enviar(operacao);
    } finally {
      _enviando = false;
    }
  }

  Future<void> verificarPendente() async {
    if (_enviando) return;
    _enviando = true;
    try {
      final operacao = await pendente();
      if (operacao != null) {
        final dados = await _consultar('transferencias/recibo.php',
            {'id_operacao': operacao.entrada['id_operacao']});
        if (dados['resposta'] is Map &&
            dados['resposta']['sucesso'] == true &&
            dados['resposta']['id_operacao'] ==
                operacao.entrada['id_operacao']) {
          await _concluir(operacao);
        } else {
          await validarPendencias(operacao.origem, operacao.destino);
          await _enviar(operacao);
        }
      }
    } catch (e) {
      if (await pendente() != null) {
        throw FalhaTransferencia(
            e is FalhaTransferencia
                ? e.mensagem
                : 'Nao foi possivel verificar a transferencia.',
            pendente: true);
      }
      rethrow;
    } finally {
      _enviando = false;
    }
  }

  Future<void> _enviar(TransferenciaPendente operacao) async {
    try {
      final resposta = await api.cliente.post('sincronizacao/operacao.php',
          data: operacao.entrada, options: _opcoes);
      if (resposta.data is! Map ||
          resposta.data['sucesso'] != true ||
          resposta.data['id_operacao'] != operacao.entrada['id_operacao']) {
        throw const FalhaTransferencia(
            'Resposta nao confirmada. Verifique a transferencia antes de tentar outra.',
            pendente: true);
      }
      await _concluir(operacao);
    } on DioException catch (erro) {
      if ([403, 409, 422].contains(erro.response?.statusCode)) {
        await _gravar(null);
        final dados = erro.response?.data;
        throw FalhaTransferencia(dados is Map
            ? (dados['mensagem'] ?? 'Transferencia recusada.').toString()
            : 'Transferencia recusada pelo servidor. Atualize a lista.');
      }
      throw const FalhaTransferencia(
          'A conexao caiu antes da confirmacao. Verifique a transferencia para recuperar o resultado sem duplicar.',
          pendente: true);
    } catch (erro) {
      if (erro is FalhaTransferencia) rethrow;
      throw const FalhaTransferencia(
          'A confirmacao ainda esta pendente neste aparelho. Verifique novamente.',
          pendente: true);
    }
  }

  Future<void> _concluir(TransferenciaPendente operacao) async {
    await ArmazenamentoCarrinhos.instancia
        .atualizarStatus(_empresa, operacao.origem.atendimento, 'Transferida');
    await api.cache?.invalidarAtendimentos();
    await _gravar(null);
  }
}
