import 'dart:convert';

import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/finalizar_pagamento/uteis/calculo_finalizacao_atendimento.dart';

import 'atendimentos_locais.dart';
import 'banco_local.dart';
import 'cache_consultas.dart';
import 'package:dio/dio.dart';

/// O recebimento permanece no mesmo banco e escopo da abertura e dos pedidos.
class RecebimentosAtendimento {
  RecebimentosAtendimento(this.banco, this.escopo);
  final BancoLocal banco;
  final String escopo;

  String _chave(String id) => 'recebimento-atendimento:$escopo:$id';

  Future<Map<String, dynamic>?> salvo(String id) async {
    var texto = await banco.ler(_chave(id));
    if (texto == null && !AtendimentosLocais.local(id)) {
      for (final abertura in await banco.db.query('operacoes',
          where: 'escopo = ? AND acao = ?', whereArgs: [escopo, 'abertura'])) {
        if (AtendimentosLocais.recibo(abertura)['id_comanda_pedido']
                ?.toString() ==
            id) {
          texto = await banco.ler(_chave(abertura['atendimento'] as String));
          break;
        }
      }
    }
    return texto == null ? null : Map<String, dynamic>.from(jsonDecode(texto));
  }

  Future<Modeloworddadoscardapio?> detalhePendente(String id) async {
    final snapshot = await salvo(id);
    if (snapshot?['ultima_operacao'] == null) return null;
    final operacao = (await banco.db.query('operacoes',
            where: 'escopo = ? AND id = ?',
            whereArgs: [escopo, snapshot!['ultima_operacao']]))
        .firstOrNull;
    if (operacao == null || operacao['estado'] == 'arquivado') return null;
    final detalhe = Modeloworddadoscardapio.fromMap(
        Map<String, dynamic>.from(snapshot['detalhe']));
    if (operacao['estado'] == 'concluido' && detalhe.status != 'Finalizada') {
      return null;
    }
    detalhe.id = id;
    return detalhe;
  }

  Future<Modeloworddadoscardapio> preparar(String id, String tipo) async {
    final estado = jsonDecode(await banco.ler('estado:$escopo') ?? '{}') as Map;
    if (estado['recebimento_atendimento_offline'] != 1) {
      throw StateError(
          'Conecte uma vez à API atualizada para preparar o recebimento offline.');
    }
    final anterior = await salvo(id);
    if (anterior?['ultima_operacao'] != null) {
      final ultima = (await banco.db.query('operacoes',
              where: 'escopo = ? AND id = ?',
              whereArgs: [escopo, anterior!['ultima_operacao']]))
          .firstOrNull;
      if (ultima == null ||
          ['conflito', 'arquivado'].contains(ultima['estado'])) {
        throw StateError(
            'Confira o recebimento pendente antes de continuar nesta conta.');
      }
      final detalhe = Modeloworddadoscardapio.fromMap(
          Map<String, dynamic>.from(anterior['detalhe']));
      if (detalhe.status == 'Finalizada') {
        throw StateError(
            'Esta conta já foi finalizada neste aparelho. Confira a sincronização.');
      }
      if (ultima['estado'] != 'concluido') return detalhe;
    }
    final locais = AtendimentosLocais(banco, escopo);
    final abertura =
        AtendimentosLocais.local(id) ? await locais.abertura(id) : null;
    if (AtendimentosLocais.local(id) && abertura == null) {
      throw StateError('A abertura original não foi encontrada.');
    }
    final real = abertura == null
        ? id
        : AtendimentosLocais.recibo(abertura)['id_comanda_pedido']?.toString();
    final identidades = {id, if (real != null) real};
    final operacoes = await banco.db.query('operacoes',
        where:
            'escopo = ? AND atendimento IN (${List.filled(identidades.length, '?').join(',')}) AND estado <> ?',
        whereArgs: [escopo, ...identidades, 'arquivado'],
        orderBy: 'criado, rowid');
    if (operacoes.any((op) => op['estado'] == 'conflito')) {
      throw StateError(
          'Existe uma alteração com conflito nesta conta. Confira as pendências antes de receber.');
    }
    if (operacoes.any((op) =>
        !['abertura', 'produtos', 'recebimento'].contains(op['acao']) &&
        op['estado'] != 'concluido')) {
      throw StateError(
          'Confirme as alterações deste atendimento antes de receber offline.');
    }

    Map<String, dynamic>? base;
    int consultaEm = 0;
    if (real != null) {
      final empresa = (jsonDecode(escopo) as List)[1];
      final usuario = (jsonDecode(escopo) as List)[2];
      for (final itens in ['Sim', 'Não']) {
        final consulta = await banco.consulta(
            escopo,
            CacheConsultas.chave(RequestOptions(
              path: 'cardapio/listar_por_id.php',
              queryParameters: {
                'id': real,
                'codigoQrcode': 'null',
                'empresa': empresa,
                'id_usuario': usuario,
                'tipo': tipo == 'mesa' ? 'Mesa' : 'Comanda',
                'mostrar_itens': itens,
              },
            )));
        if (consulta != null) {
          base = Map<String, dynamic>.from(
              jsonDecode(consulta['valor'] as String));
          consultaEm = consulta['atualizado'] as int;
          break;
        }
      }
    }
    final origem = abertura == null ? null : AtendimentosLocais.dados(abertura);
    if (base == null && abertura != null) {
      base = {
        ...Map<String, dynamic>.from(origem!['detalhe']),
        'id': id,
        'status': 'Andamento',
        'produtos': [],
        'valorTotal': '0',
      };
    }
    if (base == null || !['Andamento', 'Fechamento'].contains(base['status'])) {
      throw StateError(
          'Abra esta conta conectado uma vez para preparar seus dados offline.');
    }
    var dependenciasAnteriores = <String>[];
    if (anterior?['ultima_operacao'] != null &&
        centavosMonetarios(base['somaValorHistorico']) <
            centavosMonetarios(anterior!['detalhe']['somaValorHistorico'])) {
      base = Map<String, dynamic>.from(anterior['detalhe']);
      dependenciasAnteriores =
          List<String>.from(anterior['dependencias'] as List);
    }
    final detalhe = Modeloworddadoscardapio.fromMap(base);
    final produtos = [...?detalhe.produtos];
    final dependencias = [...dependenciasAnteriores];
    for (final op in operacoes) {
      if (op['acao'] != 'produtos' || dependencias.contains(op['id'])) continue;
      // Uma abertura sem recibo ainda nao pode ter produtos na consulta remota.
      final confirmadoEm =
          AtendimentosLocais.recibo(op)['confirmado_em'] as int?;
      if (real != null &&
          consultaEm > 0 &&
          ['concluido', 'registrado'].contains(op['estado']) &&
          (confirmadoEm == null || confirmadoEm <= consultaEm)) {
        continue;
      }
      dependencias.add(op['id'] as String);
      produtos.addAll((AtendimentosLocais.dados(op)['produtos'] as List? ?? [])
          .map(
              (p) => Modelowordprodutos.fromMap(Map<String, dynamic>.from(p))));
    }
    final totalItens =
        produtos.fold<int>(0, (soma, p) => soma + totalProdutoEmCentavos(p));
    final configRegistro = await banco.consulta(
        escopo,
        CacheConsultas.chave(RequestOptions(
          path: 'config_bigchef/listar.php',
          queryParameters: {'empresa': (jsonDecode(escopo) as List)[1]},
        )));
    if (configRegistro == null) {
      throw StateError(
          'A configuração desta empresa ainda não está salva no aparelho. Conecte à API para atualizar as permissões antes de receber offline.');
    }
    final config = Map<String, dynamic>.from(
        jsonDecode(configRegistro['valor'] as String));
    // A API envia os nomes compactos; o modelo também reconhece os nomes
    // das colunas em retratos antigos. Usa a mesma regra da tela de detalhes.
    final configuracao = ModeloConfigBigchef.fromMap(config);
    final permitido = tipo == 'mesa'
        ? configuracao.permiteFinalizarMesa
        : configuracao.permiteFinalizarComanda;
    if (!permitido) {
      throw StateError(
          'O recebimento pelo aplicativo não está habilitado para este atendimento.');
    }
    final taxa = config['habilitar_taxa_servico'] == 'Sim'
        ? (totalItens *
                numeroMonetario(config['valor_da_taxa_de_servico']) /
                100)
            .round()
        : centavosMonetarios(detalhe.valorTaxaServico);
    detalhe
      ..id = id
      ..produtos = produtos
      ..valorTaxaServico = valorDosCentavos(taxa).toStringAsFixed(2)
      ..valorTotal = valorDosCentavos(totalItens +
              taxa +
              centavosMonetarios(detalhe.valorAcrescimo) -
              centavosMonetarios(detalhe.valorDesconto))
          .toStringAsFixed(2);
    final snapshot = {
      'preparado_em': DateTime.now().millisecondsSinceEpoch,
      'detalhe': detalhe.toMap(),
      'tipo': tipo,
      'dependencias': dependencias,
      if (abertura != null) 'id_abertura': abertura['id'],
      'versao_atendimento': detalhe.versaoAtendimento ??
          (real == null
              ? null
              : (estado['atendimentos'] as Map?)?[real]?['versao']),
      'caixa_id': estado['caixa_id']?.toString() ?? '0',
    };
    if (snapshot['caixa_id'] == '0' ||
        (abertura == null &&
            '${snapshot['versao_atendimento'] ?? ''}'.isEmpty)) {
      throw StateError(
          'Conecte uma vez com seu caixa aberto para preparar o recebimento offline.');
    }
    await banco.gravar(_chave(id), jsonEncode(snapshot));
    return detalhe;
  }

  Future<({bool finalizou, double totalPago})> guardar({
    required String id,
    required Map<String, dynamic> campos,
    required String destino,
    required String nomeForma,
  }) async {
    return banco.db.transaction((tx) async {
      final texto = await BancoLocal.lerDocumento(tx, _chave(id));
      if (texto == null) {
        throw StateError('Confira a conta novamente antes de receber.');
      }
      final snapshot = Map<String, dynamic>.from(jsonDecode(texto));
      final detalhe = Modeloworddadoscardapio.fromMap(
          Map<String, dynamic>.from(snapshot['detalhe']));
      if (detalhe.status == 'Finalizada') {
        throw StateError('Esta conta já foi finalizada no aparelho.');
      }
      if (campos['modoProdutoParcial'] == true) {
        throw StateError(
            'A divisão por produtos precisa da confirmação dos itens no servidor. Use Conta inteira ou Por pessoa para receber offline.');
      }
      final conflitos = await tx.query('operacoes',
          where: 'escopo = ? AND atendimento = ? AND estado = ?',
          whereArgs: [escopo, id, 'conflito']);
      if (conflitos.isNotEmpty) {
        throw StateError('Existe uma alteração com conflito nesta conta.');
      }
      final novosItens = await tx.query('operacoes',
          where:
              'escopo = ? AND atendimento = ? AND acao = ? AND criado > ? AND estado <> ?',
          whereArgs: [
            escopo,
            id,
            'produtos',
            snapshot['preparado_em'] ?? 0,
            'arquivado'
          ]);
      if (novosItens.isNotEmpty) {
        throw StateError(
            'Novos itens foram lançados. Confira a conta antes de receber.');
      }
      final pagoAntes = centavosMonetarios(detalhe.somaValorHistorico);
      if (campos['pago_conferido_centavos'] != null &&
          campos['pago_conferido_centavos'] != pagoAntes) {
        throw StateError(
            'Outro recebimento foi salvo. Confira o saldo novamente.');
      }
      final total = centavosMonetarios(detalhe.valorTotal) -
          centavosMonetarios(detalhe.valorAcrescimo) +
          centavosMonetarios(detalhe.valorDesconto) +
          centavosMonetarios(campos['valoracrescimo']) -
          centavosMonetarios(campos['valordesconto']);
      final recebido = centavosMonetarios(campos['valor_lancamento']) -
          centavosMonetarios(campos['valortroco']);
      if (centavosMonetarios(campos['valortroco']) < 0 ||
          (campos['pagamentoSelecionado'] != 1 &&
              centavosMonetarios(campos['valortroco']) != 0)) {
        throw StateError('Confira o troco deste pagamento.');
      }
      if (total != centavosMonetarios(campos['valor_original']) ||
          recebido <= 0 ||
          pagoAntes + recebido > total) {
        throw StateError('A conta mudou. Confira os valores antes de receber.');
      }
      final pagoDepois = pagoAntes + recebido;
      final finalizou = pagoDepois == total;
      final payload = {
        ...campos,
        'id': id,
        'recebimento_offline': {
          'protocolo': 1,
          'caixa_id': snapshot['caixa_id'],
          'versao_atendimento': snapshot['versao_atendimento'],
          'total_centavos': total,
          'pago_antes_centavos': pagoAntes,
        },
        'dependencias': [
          ...List<String>.from(snapshot['dependencias'] as List),
          if (snapshot['ultima_operacao'] != null) snapshot['ultima_operacao'],
        ],
        if (snapshot['id_abertura'] != null)
          'id_abertura': snapshot['id_abertura'],
      };
      await tx.insert('operacoes', {
        'id': campos['id_operacao'],
        'escopo': escopo,
        'atendimento': id,
        'acao': 'recebimento',
        'estado': 'pendente',
        'dados': jsonEncode(payload),
        'impressoes': '[]',
        'destino': destino,
        'criado': DateTime.now().millisecondsSinceEpoch,
      });
      final pagamentos = List<Map<String, dynamic>>.from(
          detalhe.nomelancamento?.map((p) => p.toMap()) ?? []);
      pagamentos.add({
        'nome': nomeForma,
        'valor': valorDosCentavos(recebido).toStringAsFixed(2)
      });
      final dados = detalhe.toMap()
        ..['somaValorHistorico'] =
            valorDosCentavos(pagoDepois).toStringAsFixed(2)
        ..['valorTotal'] = valorDosCentavos(total).toStringAsFixed(2)
        ..['valordesconto'] = campos['valordesconto']
        ..['valoracrescimo'] = campos['valoracrescimo']
        ..['nomelancamento'] = pagamentos
        ..['status'] = finalizou ? 'Finalizada' : 'Andamento';
      if (campos['modoMultiplasPessoas'] == true) {
        final pessoas = (campos['quantidadePessoas'] as num).toInt();
        final base = centavosMonetarios(detalhe.valorBaseDivisao) > 0
            ? centavosMonetarios(detalhe.valorBaseDivisao)
            : total - pagoAntes;
        final pagas = detalhe.pessoasPagasDivisao ?? 0;
        final quota = parcelaDivisaoPersistidaEmCentavos(
            totalAtualCentavos: total,
            pagoCentavos: pagoAntes,
            pessoas: pessoas,
            valorBaseDivisaoCentavos: base,
            pessoasPagasDivisao: pagas);
        dados['quantidadepessoas'] = pessoas;
        dados['valorBaseDivisao'] = valorDosCentavos(base).toStringAsFixed(2);
        dados['pessoasPagasDivisao'] = pagas + (recebido >= quota ? 1 : 0);
      }
      snapshot['detalhe'] = dados;
      snapshot['ultima_operacao'] = campos['id_operacao'];
      await BancoLocal.gravarDocumento(tx, _chave(id), jsonEncode(snapshot));
      return (finalizou: finalizou, totalPago: valorDosCentavos(pagoDepois));
    });
  }
}
