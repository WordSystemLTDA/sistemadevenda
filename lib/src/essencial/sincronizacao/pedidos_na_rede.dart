import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/socket/protocolo_pedidos_rede.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/utils/dados_impressao_preparo.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/delivery/servicos/fila_delivery_offline.dart';
import 'package:flutter/foundation.dart';

import 'banco_local.dart';

/// Confirma apenas a copia no PC. Nunca conclui uma operacao financeira.
class PedidosNaRede {
  PedidosNaRede(this.banco, this.socket, this.usuario);
  final BancoLocal banco;
  final Server socket;
  final UsuarioProvedor usuario;
  Future<void>? _processando;
  String _alvo = '';
  String? _escopo;
  bool _descartado = false;
  bool apiIndisponivel = false;
  String destino = '';
  final _preparacoes = <String, Completer<void>>{};

  static String _prefixo(String alvo) => 'rota-pedido-rede:$alvo:';
  static String chave(String alvo, String id) =>
      ProtocoloPedidosRede.chaveRota(alvo, id);

  void configurar(String alvo, String? escopo) {
    _alvo = alvo;
    _escopo = escopo;
  }

  Future<void> _guardarCanal() async {
    final alvo = _alvo;
    final escopo = _escopo;
    final endereco = destino;
    final executor = socket.executorPedidosRede;
    if (_descartado ||
        alvo.isEmpty ||
        escopo == null ||
        !socket.connected ||
        socket.escopoPedidosRede != escopo ||
        !ProtocoloPedidosRede.executorValido(executor)) {
      return;
    }
    final key = 'canal-pedidos-rede:$alvo';
    final texto = jsonEncode(
        {'executor': executor, 'escopo': escopo, 'destino': endereco});
    if (await banco.ler(key) == texto ||
        _alvo != alvo ||
        _escopo != escopo ||
        destino != endereco ||
        !socket.connected ||
        socket.escopoPedidosRede != escopo ||
        socket.executorPedidosRede != executor) {
      return;
    }
    await banco.gravar(key, texto);
  }

  Future<String?> preparar(Map<String, Object?> op) async {
    try {
      return await _preparar(op);
    } catch (erro) {
      // A copia opcional nunca segura uma venda valida na API. Se o commit
      // local ja ocorreu, recuperar a reserva impede mudar o PC por engano.
      final salvo =
          await banco.ler(chave(op['escopo'] as String, op['id'] as String));
      if (salvo != null) return jsonDecode(salvo)['executor'] as String;
      debugPrint(
          '[PEDIDO_REDE] Copia local indisponivel; envio API preservado: $erro');
      return null;
    }
  }

  Future<String?> _preparar(Map<String, Object?> op) async {
    final alvo = op['escopo'] as String;
    final id = op['id'] as String;
    final salvo = await banco.ler(chave(alvo, id));
    if (salvo != null) {
      // Migra tambem uma copia criada pela versao anterior, sem alterar o
      // payload/id da venda nem o retrato imutavel salvo no PC.
      if (op['acao'] == 'delivery' && op['impressoes'] != '[]') {
        await banco.atualizarOperacao(id, {'impressoes': '[]'});
      }
      return jsonDecode(salvo)['executor'] as String;
    }
    // Nao adotar operacoes ja tentadas: uma resposta perdida pode ter sido
    // impressa por outro PC antes de existir a reserva na API.
    if (_escopo == null ||
        alvo != _alvo ||
        op['tentativas'] != 0 ||
        !const {'delivery', 'produtos', 'venda'}.contains(op['acao'])) {
      return null;
    }
    final estado = jsonDecode(await banco.ler('estado:$alvo') ?? '{}') as Map;
    if (estado['pedidos_rede_sem_internet'] != 1) return null;
    await _guardarCanal();
    var executor = socket.connected && socket.escopoPedidosRede == _escopo
        ? socket.executorPedidosRede
        : null;
    if (!ProtocoloPedidosRede.executorValido(executor)) {
      // Reiniciar o celular ou perder o socket nao apaga o PC ja identificado.
      // A mesma rota e reservada antes do POST; a copia espera esse PC voltar.
      final canal =
          jsonDecode(await banco.ler('canal-pedidos-rede:$alvo') ?? '{}')
              as Map;
      if (canal['escopo'] == _escopo && canal['destino'] == op['destino']) {
        executor = canal['executor'] as String?;
      }
    }
    if (!ProtocoloPedidosRede.executorValido(executor)) {
      return null;
    }
    final escopo = _escopo!;
    final conta = usuario.usuario;
    if (conta == null || conta.empresa != escopo.split('|').last) return null;
    final dados = jsonDecode(op['dados'] as String) as Map;
    if (dados['produtos'] is! List || (dados['produtos'] as List).isEmpty) {
      return null;
    }
    // Modelos recorrentes/vendas de complemento mantem o protocolo existente.
    if (dados['recorrentes'] == true || dados['id_venda_origem'] != null) {
      return null;
    }
    final tipo = op['acao'] == 'delivery'
        ? 'delivery'
        : op['acao'] == 'venda'
            ? 'balcao'
            : dados['tipo']?.toString();
    if (!const {'delivery', 'mesa', 'comanda', 'balcao'}.contains(tipo)) {
      return null;
    }
    Map<String, dynamic> retrato = {};
    if (tipo == 'delivery' &&
        FilaDeliveryOffline.local(op['atendimento'] as String)) {
      retrato = (await FilaDeliveryOffline(banco,
                  escopo: alvo,
                  empresa: conta.empresa!,
                  usuario: conta.id!,
                  destino: op['destino'] as String)
              .pedido(op['atendimento'] as String))
          .dados;
    }
    final impressoes =
        List<String>.from(jsonDecode(op['impressoes'] as String));
    if (tipo == 'delivery' && impressoes.isEmpty) {
      final grupos = <String, List<Map<String, dynamic>>>{};
      void adicionar(Modelowordprodutos produto) {
        final destino = produto.destinoDeImpressao;
        final impressora = destino?.nomeDaImpressora.trim().toLowerCase() ?? '';
        if (impressora.isEmpty || impressora == 'sem impressora') return;
        grupos.putIfAbsent(destino!.nomedopc?.trim() ?? '', () => []).add(
            DadosImpressaoPreparo.produto(produto,
                modeloValorBorda:
                    conta.configuracoes?.modelovaloradicionalpizza,
                imprimirCodigoSaboresPizza:
                    usuario.configbigchef?.imprimeCodigoSaboresPizza ?? false));
      }

      for (final mapa in dados['produtos'] as List) {
        final produto =
            Modelowordprodutos.fromMap(Map<String, dynamic>.from(mapa as Map));
        final opcoes =
            produto.opcoesPacotesListaFinal ?? produto.opcoesPacotes ?? [];
        if (opcoes.isNotEmpty && opcoes.every((o) => o.titulo == 'Combos')) {
          for (final componente
              in opcoes.expand((o) => o.produtos ?? <Modelowordprodutos>[])) {
            adicionar(componente);
          }
        } else {
          adicionar(produto);
        }
      }
      var indice = 0;
      for (final grupo in grupos.entries) {
        impressoes.add(jsonEncode({
          'idRequisicao': 'rede-$id-${indice++}',
          'protocoloImpressao': 2,
          'tipo': 'Delivery',
          'tipoImpressao': '1',
          'produtos': grupo.value,
          if (grupo.key.isNotEmpty) 'nomedopc': grupo.key,
          'comanda': 'Delivery',
          'numeroPedido': '0',
          'idEmpresa': conta.empresa,
          'idUsuario': conta.id,
          'nomeUsuario': conta.nome ?? '',
          'nomeConexao': conta.nome ?? '',
          'nomeCliente': retrato['nomeCliente'] ?? retrato['nome'] ?? '',
          'nomeEmpresa': conta.nomeEmpresa ?? '',
          'tipodeentrega': retrato['tipodeentrega'] ?? '',
          'local': [
            retrato['enderecoCliente'],
            retrato['numeroCliente'],
            retrato['bairroCliente'],
            retrato['cidadeCliente']
          ].where((v) => v != null && '$v'.trim().isNotEmpty).join(', '),
          'enviarDeVolta': true,
        }));
      }
    }
    final mensagens = impressoes.map((texto) {
      final mapa = Map<String, dynamic>.from(jsonDecode(texto) as Map);
      return jsonEncode({
        ...mapa,
        if (mapa['tipoImpressao']?.toString() == '1') 'idOperacaoRede': id
      });
    }).toList();
    final preparos = mensagens
        .map((texto) => jsonDecode(texto) as Map)
        .where((m) => m['tipoImpressao']?.toString() == '1')
        .toList();
    final pedido = {
      ...retrato,
      'nomeCliente':
          retrato['nomeCliente'] ?? preparos.firstOrNull?['nomeCliente'] ?? '',
      'identificacaoAtendimento': preparos.firstOrNull?['comanda'] ?? '',
      'tipoAtendimento': tipo,
      'produtos': dados['produtos'],
      'recurso': tipo == 'mesa'
          ? dados['id_mesa']
          : tipo == 'comanda'
              ? dados['id_comanda']
              : null,
      'observacaoDoPedido': retrato['observacaoDoPedido'] ?? dados['obs'] ?? '',
    };
    if (_alvo != alvo ||
        _escopo != escopo ||
        !identical(conta, usuario.usuario)) {
      return null;
    }
    await banco.db.transaction((tx) async {
      // Delivery recebe apenas o retrato; o preparo nasce ao avancar a etapa.
      await tx.update(
          'operacoes',
          {
            'impressoes':
                jsonEncode(tipo == 'delivery' ? <String>[] : mensagens)
          },
          where: 'id = ? AND tentativas = 0',
          whereArgs: [id]);
      await BancoLocal.gravarDocumento(
          tx,
          chave(alvo, id),
          jsonEncode({
            'executor': executor,
            'escopo': escopo,
            'id': id,
            'mensagem': {
              'tipo': ProtocoloPedidosRede.pedido,
              'protocoloPedidoRede': 1,
              'idEmpresa': conta.empresa,
              'idUsuario': conta.id,
              'executorImpressaoRede': executor,
              'idOperacaoRede': id,
              'pedido': pedido,
              'impressoes': preparos,
            },
          }));
    });
    return executor;
  }

  Future<void> processar() =>
      _processando ??= _processar().catchError((Object erro) {
        debugPrint('[PEDIDO_REDE] Envio local pendente: $erro');
      }).whenComplete(() {
        _processando = null;
      });

  Future<void> _processar() async {
    await _guardarCanal();
    final alvo = _alvo;
    final escopo = _escopo;
    if (_descartado ||
        escopo == null ||
        alvo.isEmpty ||
        !socket.connected ||
        socket.escopoPedidosRede != escopo) {
      return;
    }
    final prefixo = _prefixo(alvo);
    final rotas = await banco.db.query('documentos',
        where: 'substr(chave, 1, ?) = ?', whereArgs: [prefixo.length, prefixo]);
    for (final linha in rotas) {
      if (_descartado ||
          _alvo != alvo ||
          _escopo != escopo ||
          !socket.connected) {
        return;
      }
      final rota = jsonDecode(linha['valor'] as String) as Map;
      if (rota['executor'] != socket.executorPedidosRede ||
          rota['escopo'] != escopo) {
        continue;
      }
      final op = (await banco.db.query('operacoes',
              where: 'id = ? AND escopo = ?',
              whereArgs: [rota['id'], alvo],
              limit: 1))
          .firstOrNull;
      if (_descartado ||
          _alvo != alvo ||
          _escopo != escopo ||
          socket.escopoPedidosRede != escopo) {
        return;
      }
      if (op == null) continue;
      final estado = op['estado'];
      final confirmado = const {'registrado', 'concluido'}.contains(estado);
      final conflito = const {'conflito', 'arquivado'}.contains(estado);
      if (confirmado || conflito) {
        final resposta = confirmado ? 'confirmado' : 'conflito';
        if (rota['confirmacao'] == resposta) continue;
        socket.enviarPedidoRede({
          'escopoAtualizacao': escopo,
          'tipo': ProtocoloPedidosRede.confirmacao,
          'protocoloPedidoRede': 1,
          'idEmpresa': escopo.split('|').last,
          'idOperacaoRede': rota['id'],
          'executorImpressaoRede': rota['executor'],
          'conflito': conflito,
          if (confirmado &&
              rota['mensagem']?['pedido']?['tipoAtendimento'] == 'delivery')
            'preparoSolicitado': rota['preparoSolicitado'] == true ||
                rota['etapaDelivery'] == 'preparando',
          if (confirmado)
            'recibo': jsonDecode(op['resposta'] as String? ?? '{}'),
          if (conflito) 'erro': op['erro'] ?? 'Confira o pedido na API.',
        });
      } else if (rota['recebido'] == true &&
          rota['mensagem']?['pedido']?['tipoAtendimento'] == 'delivery') {
        socket.enviarPedidoRede({
          'escopoAtualizacao': escopo,
          'tipo': rota['preparoSolicitado'] == true &&
                  rota['etapaDelivery'] != 'preparando'
              ? ProtocoloPedidosRede.prepararDelivery
              : ProtocoloPedidosRede.consultar,
          'protocoloPedidoRede': 1,
          'idEmpresa': escopo.split('|').last,
          'idOperacaoRede': rota['id'],
          'executorImpressaoRede': rota['executor'],
        });
      } else if (rota['recebido'] != true &&
          (apiIndisponivel ||
              (op['tentativas'] as int) > 0 && op['erro'] != null)) {
        socket.enviarPedidoRede({
          ...Map<String, dynamic>.from(rota['mensagem'] as Map),
          'escopoAtualizacao': escopo
        });
      }
    }
  }

  Future<bool> receber(Map<String, dynamic> resposta) async {
    final alvo = _alvo;
    final escopo = _escopo;
    if (_descartado ||
        escopo == null ||
        socket.escopoPedidosRede != escopo ||
        resposta['idEmpresa']?.toString() != escopo.split('|').last) {
      return false;
    }
    final key = chave(alvo, resposta['idOperacaoRede'].toString());
    final mudou = await banco.db.transaction((tx) async {
      final texto = await BancoLocal.lerDocumento(tx, key);
      if (texto == null || _alvo != alvo || _escopo != escopo) return false;
      final rota = jsonDecode(texto) as Map;
      if (rota['executor'] != resposta['executorImpressaoRede'] ||
          rota['executor'] != socket.executorPedidosRede ||
          rota['escopo'] != escopo) {
        return false;
      }
      if (resposta['estado'] == 'recebido') rota['recebido'] = true;
      if (const {'aguardando', 'preparando'}
          .contains(resposta['etapaDelivery'])) {
        if (rota['etapaDelivery'] != 'preparando') {
          rota['etapaDelivery'] = resposta['etapaDelivery'];
        }
        if (resposta['etapaDelivery'] == 'preparando') {
          rota['preparoSolicitado'] = false;
        }
      }
      if (const {'confirmado', 'conflito'}.contains(resposta['estado'])) {
        rota['confirmacao'] = resposta['estado'];
      }
      if (resposta['estado'] == 'erro') rota['erro'] = resposta['erro'];
      if (jsonEncode(rota) == texto) return false;
      await BancoLocal.gravarDocumento(tx, key, jsonEncode(rota));
      return true;
    });
    if (resposta['etapaDelivery'] == 'preparando') {
      final texto = await banco.ler(key);
      if (texto != null && jsonDecode(texto)['etapaDelivery'] == 'preparando') {
        _preparacoes.remove(resposta['idOperacaoRede'])?.complete();
      }
    }
    return mudou;
  }

  void dispose() {
    _descartado = true;
  }

  Future<void> prepararDelivery(String atendimento) async {
    final id = atendimento.replaceFirst('delivery-local:', '');
    final key = chave(_alvo, id);
    await banco.db.transaction((tx) async {
      final texto = await BancoLocal.lerDocumento(tx, key);
      if (texto == null) {
        throw StateError('Aguarde o recebimento do pedido pelo PC.');
      }
      final rota = jsonDecode(texto) as Map;
      if (rota['recebido'] != true ||
          rota['mensagem']?['pedido']?['tipoAtendimento'] != 'delivery') {
        throw StateError('O PC ainda não recebeu este pedido.');
      }
      if (rota['etapaDelivery'] == 'preparando') return;
      rota['preparoSolicitado'] = true;
      await BancoLocal.gravarDocumento(tx, key, jsonEncode(rota));
    });
    final salvo = jsonDecode((await banco.ler(key))!) as Map;
    if (salvo['etapaDelivery'] == 'preparando') return;
    final espera = _preparacoes.putIfAbsent(id, () => Completer<void>());
    // A intencao duravel sera retomada quando o mesmo PC reconectar.
    unawaited(processar());
    try {
      await espera.future.timeout(const Duration(seconds: 8));
    } on TimeoutException {
      throw StateError(
          'Preparação solicitada. Aguardando confirmação do PC pelo Wi-Fi.');
    } finally {
      if (identical(_preparacoes[id], espera)) _preparacoes.remove(id);
    }
  }
}
