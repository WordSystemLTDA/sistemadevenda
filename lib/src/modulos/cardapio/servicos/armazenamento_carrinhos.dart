import 'dart:convert';

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

  Map<String, dynamic> _ler(SharedPreferences prefs) =>
      Map<String, dynamic>.from(
          jsonDecode(prefs.getString(chavePreferencias) ?? '{}') as Map);

  Future<void> _salvar(
      SharedPreferences prefs, Map<String, dynamic> dados) async {
    if (!await prefs.setString(chavePreferencias, jsonEncode(dados))) {
      throw StateError('Nao foi possivel salvar o carrinho neste aparelho.');
    }
    notifyListeners();
  }

  Future<List<Modelowordprodutos>> listar(ContextoCarrinho contexto,
      {bool recorrentes = false}) async {
    await _fila;
    final prefs = await SharedPreferences.getInstance();
    final registro = _ler(prefs)[contexto.chave];
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
        final dados = _ler(prefs);
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

  Future<bool> limpar(ContextoCarrinho contexto, {bool recorrentes = false}) =>
      _executar((prefs) async {
        final dados = _ler(prefs);
        final registro = dados[contexto.chave];
        if (registro == null) return true;
        registro[recorrentes ? 'recorrentes' : 'itens'] = <dynamic>[];
        if (recorrentes) registro['recorrentesImportados'] = true;
        await _salvar(prefs, dados);
        return true;
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
        final dados = _ler(prefs);
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
        final dados = _ler(prefs);
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
            registro['itens'] = <dynamic>[];
            registro['recorrentes'] = <dynamic>[];
            registro['encerrado'] = true;
            registro['recorrentesImportados'] = true;
            mudou = true;
          } else if (!encerrar) {
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
        final dados = _ler(prefs);
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
    } else if (['Finalizada', 'Cancelada'].contains(status)) {
      await sincronizarRecurso(
          empresa: empresa,
          tipo: 'comanda',
          idRecurso: '',
          idAtendimento: idAtendimento,
          aberto: false);
    }
  }
}
