import 'dart:convert';

import 'package:dio/dio.dart';
import '../api/socket/protocolo_pedidos_rede.dart';
import 'banco_local.dart';

/// Consulta da fila do PC. Copias recebidas nunca entram na fila de gravacoes.
class PedidosCompartilhados {
  PedidosCompartilhados(this.banco);
  final BancoLocal banco;
  String _alvo = '';
  String? _rede;
  String? _executor;
  Future<void> _fila = Future.value();

  static bool local(Object? id) => '$id'.startsWith('rede:');
  String get _chave => 'pedidos-compartilhados:$_alvo:$_rede';

  void configurar(String alvo, String? rede, String? executor) {
    _alvo = alvo;
    _rede = rede;
    _executor = executor;
  }

  Future<bool> receber(Map<String, dynamic> mensagem) {
    final alvo = _alvo, rede = _rede, executor = _executor, chave = _chave;
    final resultado = _fila.then((_) async {
      if (alvo.isEmpty ||
          rede == null ||
          alvo != _alvo ||
          rede != _rede ||
          executor != _executor ||
          mensagem['executorImpressaoRede'] != executor ||
          ProtocoloPedidosRede.mensagem(mensagem, rede,
                  aceitarResposta: true)?['tipo'] !=
              ProtocoloPedidosRede.lista) {
        return false;
      }
      final pedidos = mensagem['pedidos'] as List;
      if (pedidos.length > 10000 || (mensagem['revisao'] as int) < 0) {
        return false;
      }
      final ids = <String>{};
      for (final p in pedidos) {
        if (p is! Map ||
            !ProtocoloPedidosRede.operacaoValida(p['idOperacaoRede']) ||
            !ids.add('${p['idOperacaoRede']}') ||
            p['estado'] != 'recebido' ||
            p['pedido'] is! Map ||
            p['pedido']['produtos'] is! List ||
            (p['pedido']['produtos'] as List).length > 1000 ||
            !(p['pedido']['produtos'] as List).every((item) => item is Map) ||
            !{'mesa', 'comanda', 'delivery', 'balcao'}
                .contains(p['pedido']['tipoAtendimento'])) {
          return false;
        }
      }
      final texto = await banco.ler(chave);
      final anterior = texto == null ? null : jsonDecode(texto) as Map;
      if (anterior?['sessaoRede'] == mensagem['sessaoRede'] &&
          (anterior?['revisao'] as int? ?? -1) >=
              (mensagem['revisao'] as int)) {
        return false;
      }
      if (alvo != _alvo || rede != _rede || executor != _executor) return false;
      await banco.gravar(chave, jsonEncode(mensagem));
      return alvo == _alvo && rede == _rede && executor == _executor;
    });
    _fila = resultado.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return resultado;
  }

  Future<List<Map<String, dynamic>>> pedidos() async {
    final alvo = _alvo, rede = _rede;
    if (alvo.isEmpty || rede == null) return [];
    final texto = await banco.ler(_chave);
    if (texto == null || alvo != _alvo || rede != _rede) return [];
    final snapshot = jsonDecode(texto) as Map;
    if (_executor != null && snapshot['executorImpressaoRede'] != _executor) {
      return [];
    }
    // O aparelho de origem ja projeta sua propria fila, inclusive recibos.
    final registros = snapshot['pedidos'] as List;
    if (registros.isEmpty) return [];
    final candidatos = registros.map((p) => p['idOperacaoRede']).toList();
    final ids = <Object?>{};
    for (var inicio = 0; inicio < candidatos.length; inicio += 400) {
      final lote = candidatos.skip(inicio).take(400).toList();
      final proprios = await banco.db.query('operacoes',
          columns: ['id'],
          where:
              'escopo = ? AND id IN (${List.filled(lote.length, '?').join(',')})',
          whereArgs: [alvo, ...lote]);
      ids.addAll(proprios.map((o) => o['id']));
    }
    return [
      for (final p in registros)
        if (!ids.contains(p['idOperacaoRede']))
          Map<String, dynamic>.from(p as Map)
    ];
  }

  static double numero(Object? valor) {
    var texto = '${valor ?? '0'}'.replaceAll('R\$', '').trim();
    if (texto.contains(',')) {
      texto = texto.replaceAll('.', '').replaceAll(',', '.');
    }
    final n = double.tryParse(texto) ?? 0;
    return n.isFinite ? n : 0;
  }

  static double total(Map pedido) => pedido['valorTotal'] != null
      ? numero(pedido['valorTotal'])
      : (pedido['produtos'] as List? ?? []).fold<double>(
          0, (s, p) => s + numero(p['valorVenda']) * numero(p['quantidade']));

  static Map<String, dynamic> detalhe(Map registro) {
    final pedido = Map<String, dynamic>.from(registro['pedido'] as Map);
    final id = 'rede:${registro['idOperacaoRede']}';
    final valor = total(pedido).toStringAsFixed(2);
    return {
      'status': 'Andamento',
      'somaValorHistorico': '0',
      'nomelancamento': [],
      'valorEntrega': '0',
      'valortaxadeservico': '0',
      'valordesconto': '0',
      'valoracrescimo': '0',
      'idCliente': '0',
      'idMesa':
          pedido['tipoAtendimento'] == 'mesa' ? '${pedido['recurso']}' : '0',
      'idComanda':
          pedido['tipoAtendimento'] == 'comanda' ? '${pedido['recurso']}' : '0',
      ...pedido,
      'id': id,
      'nome': pedido['nome'] ?? pedido['nomeCliente'] ?? '',
      'valorTotal': valor,
      'valorVenda': valor,
      'valorTotalF': valor,
      'subtotal': valor,
      'dataHora': pedido['dataHora'] ?? registro['recebidoEm'] ?? '',
      'dataAbertura': pedido['dataAbertura'] ?? registro['recebidoEm'] ?? '',
      'numeroPedido': pedido['numeroPedido'] ??
          'P-${'${registro['idOperacaoRede']}'.substring(0, 8).toUpperCase()}',
      'produtos': [
        for (final p in pedido['produtos'] as List)
          {
            ...Map<String, dynamic>.from(p as Map),
            'novo': false,
            'iditensvenda':
                'rede:${registro['idOperacaoRede']}:${(pedido['produtos'] as List).indexOf(p)}'
          }
      ],
      'pedidoCompartilhadoRede': true,
    };
  }

  Future<bool> temPendencia(String id) async {
    final registros = await pedidos();
    if (registros
        .any((p) => local(id) || '${p['pedido']['idAtendimento']}' == id)) {
      return true;
    }
    // Copias anteriores ao campo idAtendimento usam o cadastro do recurso.
    final legados = registros
        .where((p) =>
            p['pedido']['idAtendimento'] == null &&
            {'mesa', 'comanda'}.contains(p['pedido']['tipoAtendimento']))
        .toList();
    if (legados.isEmpty) return false;
    final consultas = await banco.db
        .query('consultas', where: 'escopo = ?', whereArgs: [_alvo]);
    for (final c in consultas) {
      final rota = (jsonDecode(c['chave'] as String) as List).first;
      if (rota != 'mesas/listar.php' && rota != 'comandas/listar.php') continue;
      final tipo = rota == 'mesas/listar.php' ? 'mesa' : 'comanda';
      final grupos = jsonDecode(c['valor'] as String);
      if (grupos is! List) continue;
      for (final g in grupos) {
        for (final r in g['${tipo}s'] as List? ?? []) {
          if ('${r['idComandaPedido']}' == id &&
              legados.any((p) =>
                  p['pedido']['tipoAtendimento'] == tipo &&
                  '${p['pedido']['recurso']}' == '${r['id']}')) {
            return true;
          }
        }
      }
    }
    return false;
  }

  Future<Object?> projetar(RequestOptions opcoes, Object? base) async {
    final rota = Uri.parse(opcoes.path).path.replaceFirst(RegExp(r'^/+'), '');
    final q = opcoes.uri.queryParameters;
    final registros = await pedidos();
    if (registros.isEmpty) return base;
    final copia = base == null ? null : jsonDecode(jsonEncode(base));
    final pesquisa = (q['pesquisa'] ?? '').trim().toLowerCase();
    bool corresponde(Map d) =>
        pesquisa.isEmpty ||
        '${d['nome']} ${d['nomeCliente']} ${d['numeroPedido']} ${d['codigo']}'
            .toLowerCase()
            .contains(pesquisa);
    if (rota == 'mesas/listar.php' || rota == 'comandas/listar.php') {
      final tipo = rota.startsWith('mesas/') ? 'mesa' : 'comanda';
      final campo = tipo == 'mesa' ? 'mesas' : 'comandas';
      final ocupado = tipo == 'mesa' ? 'mesaOcupada' : 'comandaOcupada';
      final grupos = List<Map<String, dynamic>>.from(copia as List? ?? []);
      final recursos = [for (final g in grupos) ...g[campo] as List? ?? []];
      for (final registro
          in registros.where((p) => p['pedido']['tipoAtendimento'] == tipo)) {
        final p = registro['pedido'] as Map;
        final idRecurso = '${p['recurso']}';
        final candidatos =
            recursos.where((r) => '${r['id']}' == idRecurso).toList();
        final id = '${p['idAtendimento'] ?? ''}';
        final oficiais = candidatos
            .where((r) =>
                r[ocupado] == true &&
                (id.isEmpty ||
                    '${r['idComandaPedido']}' == id ||
                    r['idAtendimentoRede'] == id))
            .toList();
        if (oficiais.length > 1 ||
            oficiais.isEmpty && candidatos.any((r) => r[ocupado] == true)) {
          continue;
        }
        Map recurso;
        if (oficiais.isNotEmpty) {
          recurso = oficiais.single;
        } else if (candidatos.isNotEmpty) {
          recurso = candidatos.first;
          recurso[ocupado] = true;
          recurso['idComandaPedido'] = 'rede:${registro['idOperacaoRede']}';
          recurso['idAtendimentoRede'] = id;
          recurso['nomeCliente'] = p['nomeCliente'] ?? '';
          recurso['dataAbertura'] = registro['recebidoEm'];
          recurso['valor'] = '0';
        } else {
          if (!corresponde(p)) continue;
          recurso = <String, dynamic>{
            'id': idRecurso,
            'codigo': '${p['codigo'] ?? ''}',
            'nome': p['identificacaoAtendimento'] ?? idRecurso,
            'ativo': 'Sim',
            ocupado: true,
            'idComandaPedido': 'rede:${registro['idOperacaoRede']}',
            'idAtendimentoRede': id,
            'nomeCliente': p['nomeCliente'] ?? '',
            'dataAbertura': registro['recebidoEm'],
            'valor': '0'
          };
          recursos.add(recurso);
        }
        recurso['valor'] = (registro['totalCompleto'] == true
                ? total(p)
                : numero(recurso['valor']) + total(p))
            .toStringAsFixed(2);
        recurso['dataultimopedido'] = registro['recebidoEm'];
      }
      return [
        {
          'titulo': 'Ocupadas',
          campo: recursos.where((r) => r[ocupado] == true).toList()
        },
        {
          'titulo': 'Livres',
          campo: recursos.where((r) => r[ocupado] != true).toList()
        },
      ];
    }
    if (rota == 'delivery/listar_opcoes.php') {
      final dados = Map<String, dynamic>.from(
          copia as Map? ?? {'sucesso': true, 'dados': []});
      final etapas =
          List<Map<String, dynamic>>.from(dados['dados'] as List? ?? []);
      for (final r in registros
          .where((r) => r['pedido']['tipoAtendimento'] == 'delivery')) {
        final d = detalhe(r);
        if (!corresponde(d) || !_periodo(d, q)) continue;
        if ((q['tipoentrega'] ?? '0') != '0' &&
            q['tipoentrega'] != '${d['tipodeentrega']}') {
          continue;
        }
        final oficial = etapas
            .expand((e) => e['vendas'] as List? ?? [])
            .where((v) => '${v['id']}' == '${r['pedido']['idAtendimento']}')
            .firstOrNull;
        if (oficial is Map) {
          if (r['totalCompleto'] == true) {
            oficial.addAll(<String, dynamic>{...d, 'id': oficial['id']});
          }
          continue;
        }
        final impressao = r['etapaDelivery'] == 'preparando' ? '1' : '0';
        var etapa = etapas
            .where((e) => '${e['tipodeimpressao']}' == impressao)
            .firstOrNull;
        if (etapa == null) {
          etapa = {
            'id': 'rede-$impressao',
            'nomeOpcao': impressao == '1' ? 'Preparando' : 'Aguardando',
            'nomeBotao': '',
            'tipodeimpressao': impressao,
            'vendas': <dynamic>[]
          };
          etapas.add(etapa);
        }
        (etapa['vendas'] as List).insert(0, d);
      }
      dados['dados'] = etapas;
      return dados;
    }
    if (rota == 'balcao/listar.php' && (q['pagina'] ?? '1') == '1') {
      final lista = List<dynamic>.from(copia as List? ?? []);
      for (final r in registros
          .where((r) => r['pedido']['tipoAtendimento'] == 'balcao')) {
        final d = detalhe(r);
        if (!corresponde(d) || !_periodo(d, q)) continue;
        final oficial = lista
            .where((v) => '${v['id']}' == '${r['pedido']['idAtendimento']}')
            .firstOrNull;
        if (oficial is Map) {
          if (r['totalCompleto'] == true) {
            oficial['subtotal'] = d['subtotal'];
            oficial['valorTotalF'] = d['valorTotalF'];
          }
          continue;
        }
        lista.insert(0, {
          ...d,
          'nomecliente': '${d['nomeCliente'] ?? ''}',
          'numeropedido': '${d['numeroPedido']}',
          'quantidadeProdutos': '${(d['produtos'] as List).length}',
          'pagamento': '',
          'status': 'Aguardando envio (Wi-Fi)',
          'nomeusuariocompleto': '',
          'nomeusuario': '',
          'tamanhoLista': 1,
          'idtipodeentrega': '${d['tipodeentrega'] ?? ''}',
          'tipodeentrega': '',
          'nomeEmpresa': '${d['nomeEmpresa'] ?? ''}'
        });
      }
      return lista;
    }
    final id = q['id'] ?? '';
    if (rota == 'cardapio/listar_por_id.php' ||
        rota == 'delivery/listar_opcoes_por_id.php' ||
        rota == 'balcao/listar_por_id.php') {
      final remoto = registros
          .where((r) => 'rede:${r['idOperacaoRede']}' == id)
          .firstOrNull;
      if (remoto != null) {
        final d = detalhe(remoto);
        final familia = registros.where((r) =>
            r['idOperacaoRede'] != remoto['idOperacaoRede'] &&
            r['pedido']['tipoAtendimento'] ==
                remoto['pedido']['tipoAtendimento'] &&
            r['pedido']['idAtendimento'] != null &&
            r['pedido']['idAtendimento'] == remoto['pedido']['idAtendimento']);
        for (final r in familia) {
          final outro = detalhe(r);
          d['produtos'] = [
            ...d['produtos'] as List,
            ...outro['produtos'] as List
          ];
          d['valorTotal'] =
              (numero(d['valorTotal']) + numero(outro['valorTotal']))
                  .toStringAsFixed(2);
        }
        return rota == 'cardapio/listar_por_id.php'
            ? d
            : {'sucesso': true, 'dados': d};
      }
      if (copia is Map && rota == 'cardapio/listar_por_id.php') {
        for (final r in registros
            .where((r) => '${r['pedido']['idAtendimento']}' == id)) {
          final d = detalhe(r);
          if (r['totalCompleto'] == true) {
            copia.addAll(<String, dynamic>{...d, 'id': id});
          } else {
            copia['produtos'] = [
              ...copia['produtos'] as List? ?? [],
              ...d['produtos'] as List
            ];
            copia['valorTotal'] =
                (numero(copia['valorTotal']) + numero(d['valorTotal']))
                    .toStringAsFixed(2);
          }
        }
      }
    }
    return copia ?? base;
  }

  static bool _periodo(Map d, Map<String, String> q) {
    final data = DateTime.tryParse('${d['dataHora']}');
    if (data == null) return true;
    final dia = data.toIso8601String().substring(0, 10);
    return (q['dataInicio'] == null || dia.compareTo(q['dataInicio']!) >= 0) &&
        (q['dataFim'] == null || dia.compareTo(q['dataFim']!) <= 0);
  }
}
