import 'dart:convert';

import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/seguranca_pendencias.dart';

import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ArmazenamentoCarrinhos extends ChangeNotifier {
  static final instancia = ArmazenamentoCarrinhos();
  static const chavePreferencias = 'carrinhos_por_atendimento_v1';
  Future<void>? _fila;

  // Serializa leitura + escrita para nao perder itens em toques simultaneos.
  Future<T> _executar<T>(Future<T> Function(SharedPreferences) acao) {
    Future<T> executar() async => acao(await SharedPreferences.getInstance());
    final anterior = _fila;
    final resultado =
        anterior == null ? executar() : anterior.then((_) => executar());
    late final Future<void> fim;
    void concluir() {
      if (identical(_fila, fim)) _fila = null;
    }

    fim = resultado.then<void>((_) => concluir(),
        onError: (Object _, StackTrace __) => concluir());
    _fila = fim;
    return resultado;
  }

  Future<Map<String, dynamic>> _ler(SharedPreferences prefs) async {
    final banco = BancoLocal.instancia;
    final valor = banco == null
        ? prefs.getString(chavePreferencias)
        : await banco.ler(banco.chaveCarrinhos);
    return Map<String, dynamic>.from(jsonDecode(valor ?? '{}') as Map);
  }

  /// Integra transferencias atomicas do carrinho para outras filas SQLite.
  /// A acao deve persistir antes de retornar e nao chamar outro metodo desta fila.
  Future<T> executarComCarrinhosBloqueados<T>(Future<T> Function() acao) =>
      _executar((_) async {
        final resultado = await acao();
        notifyListeners();
        return resultado;
      });

  Future<void> _salvar(
      SharedPreferences prefs, Map<String, dynamic> dados) async {
    final banco = BancoLocal.instancia;
    if (banco != null) {
      await banco.gravar(banco.chaveCarrinhos, jsonEncode(dados));
    } else if (!await prefs.setString(chavePreferencias, jsonEncode(dados))) {
      throw StateError('Nao foi possivel salvar o carrinho neste aparelho.');
    }
    notifyListeners();
  }

  Future<List<Modelowordprodutos>> listar(ContextoCarrinho contexto,
      {bool recorrentes = false}) async {
    await _fila;
    final prefs = await SharedPreferences.getInstance();
    final registro = (await _ler(prefs))[contexto.chave];
    if (!contexto.valido || registro == null || registro['encerrado'] == true) {
      return [];
    }
    return (registro[recorrentes ? 'recorrentes' : 'itens'] as List? ?? [])
        .map((item) =>
            Modelowordprodutos.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<bool> alterar(ContextoCarrinho contexto,
          void Function(List<Modelowordprodutos>) alterar,
          {bool recorrentes = false}) =>
      _executar((prefs) async {
        if (!contexto.valido) return false;
        final dados = await _ler(prefs);
        final registro = Map<String, dynamic>.from(dados[contexto.chave] ??
            {
              ...contexto.toMap(),
              'itens': <dynamic>[],
              'recorrentes': <dynamic>[],
            });
        if (registro['encerrado'] == true || registro['bloqueado'] == true) {
          return false;
        }
        final campo = recorrentes ? 'recorrentes' : 'itens';
        final itens = (registro[campo] as List? ?? [])
            .map((item) => Modelowordprodutos.fromMap(
                Map<String, dynamic>.from(item as Map)))
            .toList();
        alterar(itens);
        registro[campo] = itens.map((item) => item.toMap()).toList();
        if (recorrentes) registro['recorrentesImportados'] = true;
        if (contexto.idRecurso.isNotEmpty) registro.addAll(contexto.toMap());
        dados[contexto.chave] = registro;
        await _salvar(prefs, dados);
        return true;
      });

  Future<bool> temRascunhoDeAtendimentos(
      String empresa, List<String> ids) async {
    await _fila;
    final dados = await _ler(await SharedPreferences.getInstance());
    return dados.values.any((registro) =>
        registro['empresa'] == empresa &&
        ids.contains(registro['idAtendimento']) &&
        (registro['itens'] as List? ?? []).isNotEmpty);
  }

  Future<bool> limpar(ContextoCarrinho contexto, {bool recorrentes = false}) =>
      _executar((prefs) async {
        final dados = await _ler(prefs);
        final registro = dados[contexto.chave];
        if (registro == null) return true;
        registro[recorrentes ? 'recorrentes' : 'itens'] = <dynamic>[];
        if (recorrentes) registro['recorrentesImportados'] = true;
        await _salvar(prefs, dados);
        return true;
      });

  Future<String> finalizarDuravel({
    required String escopo,
    required ContextoCarrinho contexto,
    required List<Modelowordprodutos> itens,
    required Map<String, dynamic> dados,
    required List<String> impressoes,
    required String destino,
    bool recorrentes = false,
    String acao = 'produtos',
    String? idOperacao,
    String? atendimentoOperacao,
  }) =>
      _executar((_) async {
        final banco = BancoLocal.instancia;
        if (banco == null) throw StateError('Banco local indisponivel.');
        final id = await banco.guardarPedido(
          escopo: escopo,
          chaveCarrinho: contexto.chave,
          atendimento: atendimentoOperacao ?? contexto.idAtendimento,
          itens: itens.map((e) => e.toMap()).toList(),
          dados: dados,
          impressoes: impressoes,
          destino: destino,
          recorrentes: recorrentes,
          acao: acao,
          idOperacao: idOperacao,
        );
        notifyListeners();
        return id;
      });

  /// Recuperacao e retirada da fila fazem parte do mesmo commit. Uma falha de
  /// disco ou encerramento do aplicativo nunca deixa duas copias enviaveis.
  Future<void> recuperarOperacao({
    required String id,
    required String escopo,
    required String chaveDocumento,
    required ContextoCarrinho contexto,
    required List<Modelowordprodutos> produtos,
  }) =>
      _executar((_) async {
        final banco = BancoLocal.instancia;
        if (banco == null || !contexto.valido) {
          throw StateError('Banco local ou atendimento indisponivel.');
        }
        await banco.db.transaction((tx) async {
          final op = (await tx.query('operacoes',
                  where: 'id = ? AND escopo = ?', whereArgs: [id, escopo]))
              .firstOrNull;
          if (op == null || !SegurancaPendencias.podeRecuperar(op)) {
            throw StateError(
                'O envio precisa ser confirmado pelo servidor antes de editar.');
          }
          final carrinhos = Map<String, dynamic>.from(jsonDecode(
                  await BancoLocal.lerDocumento(tx, chaveDocumento) ?? '{}')
              as Map);
          final registro = Map<String, dynamic>.from(
              carrinhos[contexto.chave] ?? contexto.toMap());
          if (registro['encerrado'] == true || registro['bloqueado'] == true) {
            throw StateError('O atendimento ja foi encerrado ou bloqueado.');
          }
          registro['itens'] = [
            ...registro['itens'] as List? ?? [],
            ...produtos.map((p) => p.toMap()),
          ];
          carrinhos[contexto.chave] = registro;
          await BancoLocal.gravarDocumento(
              tx, chaveDocumento, jsonEncode(carrinhos));
          await tx.update(
              'operacoes',
              {
                'estado': 'arquivado',
                'erro': 'Pedido voltou para o carrinho para edicao.',
                'proxima': 0,
              },
              where: 'id = ? AND escopo = ?',
              whereArgs: [id, escopo]);
        });
        notifyListeners();
      });

  Future<void> arquivarRascunhoBloqueado({
    required ContextoCarrinho contexto,
    required String chaveDocumento,
  }) =>
      _executar((_) async {
        final banco = BancoLocal.instancia;
        if (banco == null) throw StateError('Banco local indisponivel.');
        await banco.db.transaction((tx) async {
          final carrinhos = Map<String, dynamic>.from(jsonDecode(
                  await BancoLocal.lerDocumento(tx, chaveDocumento) ?? '{}')
              as Map);
          final registro = carrinhos[contexto.chave];
          if (registro == null) return;
          if (registro['encerrado'] != true && registro['bloqueado'] != true) {
            throw StateError('Este atendimento nao esta bloqueado.');
          }
          await BancoLocal.gravarDocumento(
              tx,
              'rascunho-arquivado:${BancoLocal.novoId()}',
              jsonEncode({
                'origem': chaveDocumento,
                'arquivado_em': DateTime.now().toIso8601String(),
                'carrinho': registro,
              }));
          registro['itens'] = [];
          registro['recorrentes'] = [];
          await BancoLocal.gravarDocumento(
              tx, chaveDocumento, jsonEncode(carrinhos));
        });
        notifyListeners();
      });

  Future<void> conferirRascunhosNoServidor({
    required String chaveDocumento,
    required String empresa,
    required Map<String, String> identidadesConsultadas,
    required Map atendimentos,
  }) =>
      _executar((_) async {
        final banco = BancoLocal.instancia;
        if (banco == null) return;
        final mudou = await banco.db.transaction((tx) async {
          final carrinhos = Map<String, dynamic>.from(jsonDecode(
                  await BancoLocal.lerDocumento(tx, chaveDocumento) ?? '{}')
              as Map);
          var mudou = false;
          for (final registro in carrinhos.values.whereType<Map>()) {
            if (registro['empresa'] != empresa) continue;
            final idServidor =
                identidadesConsultadas[registro['idAtendimento']];
            if (idServidor == null) continue;
            final atendimento = atendimentos[idServidor];
            if (atendimento == null) {
              if (registro['encerrado'] != true ||
                  registro['encerradoConfirmado'] != true) {
                registro['encerrado'] = true;
                registro['encerradoConfirmado'] = true;
                mudou = true;
              }
            } else if (atendimento is Map) {
              final bloqueado = atendimento['status'] != 'Andamento';
              if (registro['bloqueado'] != bloqueado) {
                registro['bloqueado'] = bloqueado;
                mudou = true;
              }
            }
          }
          if (mudou) {
            await BancoLocal.gravarDocumento(
                tx, chaveDocumento, jsonEncode(carrinhos));
          }
          return mudou;
        });
        if (mudou) notifyListeners();
      });

  Future<bool> substituirItem(
    ContextoCarrinho contexto,
    int index,
    Modelowordprodutos original,
    Modelowordprodutos editado, {
    bool recorrentes = false,
  }) {
    final assinatura = jsonEncode(original.toMap());
    final copia = Modelowordprodutos.fromMap(editado.toMap())
      ..conferidoNoCarrinho = false;
    return alterar(contexto, (itens) {
      // Confere dentro da mesma escrita para nao sobrescrever outro item.
      if (index < 0 ||
          index >= itens.length ||
          jsonEncode(itens[index].toMap()) != assinatura) {
        throw StateError(
            'O item do carrinho foi alterado. Abra a edição novamente.');
      }
      itens[index] = copia;
    }, recorrentes: recorrentes);
  }

  Future<bool> definirConferencia(
    ContextoCarrinho contexto,
    int index,
    Modelowordprodutos original,
    bool conferido, {
    bool recorrentes = false,
  }) {
    final assinatura = jsonEncode(original.toMap());
    return alterar(contexto, (itens) {
      // A marcacao vale somente para o item e a versao que o usuario conferiu.
      if (index < 0 ||
          index >= itens.length ||
          jsonEncode(itens[index].toMap()) != assinatura) {
        throw StateError('O item do carrinho foi alterado. Confira novamente.');
      }
      itens[index].conferidoNoCarrinho = conferido;
    }, recorrentes: recorrentes);
  }

  // O formato antigo dos recorrentes tem atendimento; o carrinho global nao tem.
  // Esta importacao so ocorre depois da confirmacao do atendimento pela API.
  Future<void> importarRecorrentes(ContextoCarrinho contexto) =>
      _executar((prefs) async {
        if (!contexto.valido) return;
        final antigos =
            (jsonDecode(prefs.getString('itens_recorrentes') ?? '[]') as List)
                .map((item) => Map<String, dynamic>.from(
                    item is String ? jsonDecode(item) : item))
                .toList();
        final antigo = antigos
            .where((item) => item['idComandaPedido'] == contexto.idAtendimento)
            .firstOrNull;
        if (antigo == null) return;
        final dados = await _ler(prefs);
        final registro = Map<String, dynamic>.from(
            dados[contexto.chave] ?? contexto.toMap());
        if (registro['encerrado'] == true ||
            registro['recorrentesImportados'] == true) {
          return;
        }
        registro['recorrentes'] = (antigo['produtos'] as List)
            .map((item) => item is String ? jsonDecode(item) : item)
            .toList();
        registro['recorrentesImportados'] = true;
        dados[contexto.chave] = registro;
        await _salvar(prefs, dados);
        antigos.remove(antigo);
        await prefs.setString('itens_recorrentes', jsonEncode(antigos));
      });

  Future<void> sincronizarRecurso({
    required String empresa,
    required String tipo,
    required String idRecurso,
    required String? idAtendimento,
    required bool aberto,
    bool bloqueado = false,
  }) =>
      _executar((prefs) async {
        final dados = await _ler(prefs);
        var mudou = false;
        for (final registro in dados.values) {
          if (registro['empresa'] != empresa) continue;
          final mesmoAtendimento = idAtendimento != null &&
              idAtendimento != '0' &&
              registro['idAtendimento'] == idAtendimento &&
              (registro['tipo'] == 'mesa' || registro['tipo'] == 'comanda');
          final mesmoRecurso = idRecurso.isNotEmpty &&
              idRecurso != '0' &&
              registro['tipo'] == tipo &&
              registro['idRecurso'] == idRecurso;
          if (!mesmoAtendimento && !mesmoRecurso) continue;
          final encerrar =
              !aberto || registro['idAtendimento'] != idAtendimento;
          if (encerrar && registro['encerrado'] != true) {
            // Preserva rascunhos para recuperacao; nunca os transfere ao novo atendimento.
            registro['encerrado'] = true;
            registro['recorrentesImportados'] = true;
            mudou = true;
          } else if (!encerrar && registro['encerradoConfirmado'] != true) {
            if (registro['encerrado'] == true ||
                registro['bloqueado'] != bloqueado) {
              registro['encerrado'] = false;
              registro['bloqueado'] = bloqueado;
              mudou = true;
            }
          }
        }
        if (!aberto &&
            idAtendimento != null &&
            idAtendimento.isNotEmpty &&
            idAtendimento != '0') {
          final contexto = ContextoCarrinho(
              empresa: empresa,
              tipo: tipo,
              idAtendimento: idAtendimento,
              idRecurso: idRecurso);
          if (!dados.containsKey(contexto.chave)) {
            dados[contexto.chave] = {
              ...contexto.toMap(),
              'encerrado': true,
              'recorrentesImportados': true,
              'itens': [],
              'recorrentes': []
            };
            mudou = true;
          }
        }
        if (mudou) await _salvar(prefs, dados);
      });

  Future<void> atualizarStatus(
      String empresa, String idAtendimento, String? status) async {
    if (status == null || status.isEmpty) return;
    if (status == 'Andamento' || status == 'Fechamento') {
      await _executar((prefs) async {
        final dados = await _ler(prefs);
        var mudou = false;
        final contexto = ContextoCarrinho(
            empresa: empresa, tipo: 'comanda', idAtendimento: idAtendimento);
        if (status == 'Fechamento' &&
            contexto.valido &&
            !dados.containsKey(contexto.chave)) {
          dados[contexto.chave] = {
            ...contexto.toMap(),
            'itens': [],
            'recorrentes': []
          };
        }
        for (final registro in dados.values) {
          if (registro['empresa'] == empresa &&
              registro['encerradoConfirmado'] != true &&
              registro['idAtendimento'] == idAtendimento &&
              (registro['tipo'] == 'comanda' || registro['tipo'] == 'mesa')) {
            final bloqueado = status == 'Fechamento';
            if (registro['bloqueado'] != bloqueado ||
                (status == 'Andamento' && registro['encerrado'] == true)) {
              registro['bloqueado'] = bloqueado;
              if (status == 'Andamento') registro['encerrado'] = false;
              mudou = true;
            }
          }
        }
        if (mudou) await _salvar(prefs, dados);
      });
    } else if (['Finalizada', 'Cancelada', 'Transferida'].contains(status)) {
      await sincronizarRecurso(
          empresa: empresa,
          tipo: 'comanda',
          idRecurso: '',
          idAtendimento: idAtendimento,
          aberto: false);
    }
  }
}
