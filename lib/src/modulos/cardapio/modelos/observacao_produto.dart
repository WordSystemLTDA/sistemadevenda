import 'dart:convert';

import 'modelo_dados_opcoes_pacotes.dart';
import 'modelo_opcoes_pacotes.dart';

const int idGrupoObservacaoProduto = 12;
const int idGrupoObservacaoProdutoLegado = 11;
const int maxCaracteresObservacaoProduto = 200;

String normalizarObservacaoProduto(Object? valor,
    {int maxCaracteres = maxCaracteresObservacaoProduto}) {
  final texto = (valor ?? '').toString();
  final semControles =
      texto.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), ' ');
  final normalizado = semControles.replaceAll(RegExp(r'\s+'), ' ').trim();
  final runes = normalizado.runes.toList();
  if (runes.length <= maxCaracteres) return normalizado;
  return String.fromCharCodes(runes.take(maxCaracteres)).trimRight();
}

bool tituloGrupoObservacao(Object? titulo) {
  final normalizado = (titulo ?? '').toString().trim().toLowerCase();
  return normalizado == 'observação' || normalizado == 'observacao';
}

bool grupoObservacaoProduto(ModeloOpcoesPacotes opcao) =>
    opcao.id == idGrupoObservacaoProduto ||
    tituloGrupoObservacao(opcao.titulo) ||
    (opcao.id == idGrupoObservacaoProdutoLegado && opcao.tipo == 7);

bool grupoObservacaoProdutoMap(Map<String, dynamic> opcao) {
  final id = int.tryParse('${opcao['id'] ?? ''}');
  final tipo = int.tryParse('${opcao['tipo'] ?? ''}');
  return id == idGrupoObservacaoProduto ||
      tituloGrupoObservacao(opcao['titulo']) ||
      (id == idGrupoObservacaoProdutoLegado && tipo == 7);
}

ModeloOpcoesPacotes montarGrupoObservacaoProduto(Object? valor) {
  final texto = normalizarObservacaoProduto(valor);
  return ModeloOpcoesPacotes(
    id: idGrupoObservacaoProduto,
    titulo: 'Observação',
    tipo: 7,
    obrigatorio: false,
    dados: [
      ModeloDadosOpcoesPacotes(
        id: '0',
        nome: texto,
        foto: '',
        estaSelecionado: false,
        excluir: false,
      )
    ],
  );
}

List<Map<String, dynamic>> normalizarProdutosParaEnvio(Object? valor) =>
    _lista(valor)
        .map(normalizarProdutoParaEnvio)
        .where((produto) => produto.isNotEmpty)
        .toList();

Map<String, dynamic> normalizarProdutoParaEnvio(Object? valor) {
  final produto = _mapa(valor);
  if (produto.isEmpty) return produto;
  final observacao = normalizarObservacaoProduto(produto['observacao']);
  produto['observacao'] = observacao.isNotEmpty
      ? observacao
      : _observacaoNasOpcoes(produto['opcoesPacotesListaFinal']) ??
          _observacaoNasOpcoes(produto['opcoesPacotes']) ??
          '';
  for (final campo in ['opcoesPacotesListaFinal', 'opcoesPacotes']) {
    if (produto.containsKey(campo)) {
      produto[campo] = _normalizarOpcoes(produto[campo]);
    }
  }
  return produto;
}

List<Map<String, dynamic>> _normalizarOpcoes(Object? valor) => _lista(valor)
        .map(_mapa)
        .where((opcao) => opcao.isNotEmpty && !grupoObservacaoProdutoMap(opcao))
        .map((opcao) {
      if (opcao.containsKey('produtos')) {
        opcao['produtos'] = normalizarProdutosParaEnvio(opcao['produtos']);
      }
      if (opcao.containsKey('opcoesPacote')) {
        opcao['opcoesPacote'] = _normalizarOpcoes(opcao['opcoesPacote']);
      }
      return opcao;
    }).toList();

String? _observacaoNasOpcoes(Object? valor) {
  for (final opcao in _lista(valor).map(_mapa)) {
    if (!grupoObservacaoProdutoMap(opcao)) continue;
    final dados = _lista(opcao['dados']).map(_mapa);
    if (dados.isEmpty) continue;
    final texto = normalizarObservacaoProduto(dados.first['nome']);
    if (texto.isNotEmpty) return texto;
  }
  return null;
}

List<Object?> _lista(Object? valor) {
  if (valor is List) return valor;
  if (valor is String && valor.trim().isNotEmpty) {
    try {
      final decodificado = jsonDecode(valor);
      if (decodificado is List) return decodificado;
    } catch (_) {
      return const [];
    }
  }
  return const [];
}

Map<String, dynamic> _mapa(Object? valor) {
  if (valor is Map) {
    return {
      for (final entrada in valor.entries)
        if (entrada.key != null) entrada.key.toString(): entrada.value,
    };
  }
  if (valor is String && valor.trim().isNotEmpty) {
    try {
      final decodificado = jsonDecode(valor);
      if (decodificado is Map) return _mapa(decodificado);
    } catch (_) {
      return const {};
    }
  }
  return const {};
}
