import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProdutoCardapioDelivery {
  const ProdutoCardapioDelivery({
    required this.nome,
    required this.valor,
  });

  factory ProdutoCardapioDelivery.fromMap(Map<dynamic, dynamic> dados) {
    return ProdutoCardapioDelivery(
      nome: (dados['nome'] ?? '').toString().trim(),
      valor: _converterValor(dados['valor'] ?? dados['valor_venda']),
    );
  }

  final String nome;
  final double valor;

  String get valorFormatado => NumberFormat.currency(
        locale: 'pt_BR',
        symbol: r'R$',
        decimalDigits: 2,
      ).format(valor);

  static double _converterValor(dynamic valor) {
    if (valor is num) return valor.toDouble();
    var texto = (valor ?? '').toString().replaceAll(RegExp(r'[^0-9,.-]'), '');
    if (texto.contains(',')) {
      texto = texto.replaceAll('.', '').replaceAll(',', '.');
    }
    return double.tryParse(texto) ?? 0;
  }
}

class DadosCardapioDelivery {
  DadosCardapioDelivery({
    required List<String> ingredientes,
    required List<ProdutoCardapioDelivery> produtos,
  })  : ingredientes = List.unmodifiable(ingredientes),
        produtos = List.unmodifiable(produtos);

  final List<String> ingredientes;
  final List<ProdutoCardapioDelivery> produtos;
}

/// Gera uma imagem leve e pronta para envio no WhatsApp, sem depender de
/// captura de tela ou de um widget visivel.
class GeradorCardapioDelivery {
  static const double _largura = 1080;
  static const double _altura = 1350;
  static const _creme = Color(0xfffff5e4);
  static const _vermelho = Color(0xffa80808);
  static const _vinho = Color(0xff3b1010);

  static Future<Uint8List> gerar({
    required String nomeEmpresa,
    required List<String> ingredientes,
    List<ProdutoCardapioDelivery> produtos = const [],
    DateTime? data,
  }) async {
    final itens = ingredientes
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    final produtosPorNome = <String, ProdutoCardapioDelivery>{};
    for (final produto in produtos) {
      final nome = produto.nome.trim();
      if (nome.isEmpty) continue;
      produtosPorNome.putIfAbsent(
        nome.toLowerCase(),
        () => ProdutoCardapioDelivery(nome: nome, valor: produto.valor),
      );
    }
    final opcoes = produtosPorNome.values.toList();
    if (itens.isEmpty && opcoes.isEmpty) {
      throw StateError(
          'Não há ingredientes ou produtos configurados para hoje.');
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const tamanho = Size(_largura, _altura);
    final fundo = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff7f0606), Color(0xffc91610), Color(0xff650202)],
        stops: [0, .52, 1],
      ).createShader(Offset.zero & tamanho);
    canvas.drawRect(Offset.zero & tamanho, fundo);

    final decoracao = Paint()..color = Colors.white.withValues(alpha: .075);
    canvas.drawCircle(const Offset(50, 165), 205, decoracao);
    canvas.drawCircle(const Offset(1040, 1040), 290, decoracao);
    canvas.drawCircle(
      const Offset(925, 80),
      110,
      Paint()..color = Colors.black.withValues(alpha: .055),
    );

    final cabecalho = RRect.fromRectAndRadius(
      const Rect.fromLTWH(62, 52, 956, 205),
      const Radius.circular(42),
    );
    _sombra(canvas, cabecalho);
    canvas.drawRRect(cabecalho, Paint()..color = _creme);
    canvas.drawRRect(
      cabecalho,
      Paint()
        ..color = _vinho
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );

    _texto(
      canvas,
      nomeEmpresa.trim().isEmpty ? 'RESTAURANTE' : nomeEmpresa.trim(),
      const Rect.fromLTWH(112, 82, 856, 71),
      tamanho: 46,
      peso: FontWeight.w900,
      cor: const Color(0xff2c1712),
      maxLinhas: 1,
      alinhamento: TextAlign.center,
    );
    _texto(
      canvas,
      DateFormat('dd/MM/yyyy').format(data ?? DateTime.now()),
      const Rect.fromLTWH(120, 159, 840, 49),
      tamanho: 30,
      peso: FontWeight.w700,
      cor: _vermelho,
      maxLinhas: 1,
      alinhamento: TextAlign.center,
    );

    final faixa = RRect.fromRectAndRadius(
      const Rect.fromLTWH(44, 286, 992, 105),
      const Radius.circular(25),
    );
    _sombra(canvas, faixa, deslocamento: 8, opacidade: .13);
    canvas.drawRRect(faixa, Paint()..color = _creme);
    _texto(
      canvas,
      'CARDÁPIO DO DIA',
      const Rect.fromLTWH(88, 301, 904, 73),
      tamanho: 55,
      peso: FontWeight.w900,
      cor: _vermelho,
      maxLinhas: 1,
      alinhamento: TextAlign.center,
    );

    const topoConteudo = 420.0;
    const fimConteudo = 1192.0;
    const espacoSecoes = 22.0;
    if (itens.isNotEmpty && opcoes.isNotEmpty) {
      final linhasProdutos =
          opcoes.length > 7 ? (opcoes.length / 2).ceil() : opcoes.length;
      final alturaProdutos =
          (118 + (linhasProdutos * 55.0)).clamp(260.0, 500.0);
      final alturaIngredientes =
          fimConteudo - topoConteudo - espacoSecoes - alturaProdutos;
      _desenharIngredientes(
        canvas,
        itens,
        Rect.fromLTWH(52, topoConteudo, 976, alturaIngredientes),
      );
      _desenharProdutos(
        canvas,
        opcoes,
        Rect.fromLTWH(
          52,
          topoConteudo + alturaIngredientes + espacoSecoes,
          976,
          alturaProdutos,
        ),
      );
    } else if (itens.isNotEmpty) {
      _desenharIngredientes(
        canvas,
        itens,
        const Rect.fromLTWH(52, topoConteudo, 976, fimConteudo - topoConteudo),
      );
    } else {
      _desenharProdutos(
        canvas,
        opcoes,
        const Rect.fromLTWH(52, topoConteudo, 976, fimConteudo - topoConteudo),
      );
    }

    final rodape = RRect.fromRectAndRadius(
      const Rect.fromLTWH(120, 1221, 840, 82),
      const Radius.circular(41),
    );
    _sombra(canvas, rodape, deslocamento: 7, opacidade: .13);
    canvas.drawRRect(rodape, Paint()..color = _creme);
    _texto(
      canvas,
      'Faça seu pedido pelo WhatsApp',
      const Rect.fromLTWH(160, 1237, 760, 50),
      tamanho: 32,
      peso: FontWeight.w900,
      cor: _vermelho,
      maxLinhas: 1,
      alinhamento: TextAlign.center,
    );

    final imagem = await recorder.endRecording().toImage(
          _largura.toInt(),
          _altura.toInt(),
        );
    final bytes = await imagem.toByteData(format: ui.ImageByteFormat.png);
    imagem.dispose();
    if (bytes == null) {
      throw StateError('Não foi possível gerar a imagem do cardápio.');
    }
    return bytes.buffer.asUint8List();
  }

  static void _desenharIngredientes(
    Canvas canvas,
    List<String> itens,
    Rect area,
  ) {
    final cartao = RRect.fromRectAndRadius(area, const Radius.circular(34));
    canvas.drawRRect(
      cartao,
      Paint()..color = Colors.white.withValues(alpha: .10),
    );
    canvas.drawRRect(
      cartao,
      Paint()
        ..color = _creme.withValues(alpha: .62)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    _texto(
      canvas,
      'INGREDIENTES DO DIA',
      Rect.fromLTWH(area.left + 34, area.top + 17, area.width - 68, 48),
      tamanho: 28,
      peso: FontWeight.w900,
      cor: _creme,
      maxLinhas: 1,
    );
    canvas.drawLine(
      Offset(area.left + 34, area.top + 76),
      Offset(area.right - 34, area.top + 76),
      Paint()
        ..color = _creme.withValues(alpha: .35)
        ..strokeWidth = 2,
    );

    final corpo = Rect.fromLTRB(
      area.left + 30,
      area.top + 88,
      area.right - 30,
      area.bottom - 22,
    );
    final maximoLinhas = math.max(1, (corpo.height / 47).floor());
    final colunas = (itens.length / maximoLinhas).ceil().clamp(1, 3).toInt();
    final linhas = (itens.length / colunas).ceil();
    const espaco = 18.0;
    final largura = (corpo.width - espaco * (colunas - 1)) / colunas;
    final alturaLinha = corpo.height / linhas;
    final tamanhoFonte = (alturaLinha * .51).clamp(19.0, 39.0);

    canvas.save();
    canvas.clipRRect(cartao);
    for (var indice = 0; indice < itens.length; indice++) {
      final coluna = indice ~/ linhas;
      final linha = indice % linhas;
      final esquerda = corpo.left + coluna * (largura + espaco);
      final topo = corpo.top + linha * alturaLinha;
      canvas.drawCircle(
        Offset(esquerda + 8, topo + alturaLinha / 2),
        math.max(3.5, tamanhoFonte * .12),
        Paint()..color = _creme,
      );
      _texto(
        canvas,
        itens[indice],
        Rect.fromLTWH(
          esquerda + 26,
          topo,
          largura - 26,
          alturaLinha,
        ),
        tamanho: tamanhoFonte,
        peso: FontWeight.w800,
        cor: Colors.white,
        maxLinhas: alturaLinha >= 60 ? 2 : 1,
      );
    }
    canvas.restore();
  }

  static void _desenharProdutos(
    Canvas canvas,
    List<ProdutoCardapioDelivery> produtos,
    Rect area,
  ) {
    final cartao = RRect.fromRectAndRadius(area, const Radius.circular(34));
    _sombra(canvas, cartao, deslocamento: 8, opacidade: .14);
    canvas.drawRRect(cartao, Paint()..color = _creme);
    _texto(
      canvas,
      'OPÇÕES E VALORES',
      Rect.fromLTWH(area.left + 34, area.top + 17, area.width - 68, 48),
      tamanho: 28,
      peso: FontWeight.w900,
      cor: _vermelho,
      maxLinhas: 1,
    );
    canvas.drawLine(
      Offset(area.left + 34, area.top + 76),
      Offset(area.right - 34, area.top + 76),
      Paint()
        ..color = _vermelho.withValues(alpha: .22)
        ..strokeWidth = 2,
    );

    final corpo = Rect.fromLTRB(
      area.left + 30,
      area.top + 88,
      area.right - 30,
      area.bottom - 20,
    );
    final maximoLinhas = math.max(1, (corpo.height / 48).floor());
    final colunas = (produtos.length / maximoLinhas).ceil().clamp(1, 2).toInt();
    final linhas = (produtos.length / colunas).ceil();
    const espaco = 30.0;
    final largura = (corpo.width - espaco * (colunas - 1)) / colunas;
    final alturaLinha = corpo.height / linhas;
    final tamanhoFonte = (alturaLinha * .40).clamp(18.0, 31.0);

    canvas.save();
    canvas.clipRRect(cartao);
    for (var indice = 0; indice < produtos.length; indice++) {
      final coluna = indice ~/ linhas;
      final linha = indice % linhas;
      final esquerda = corpo.left + coluna * (largura + espaco);
      final topo = corpo.top + linha * alturaLinha;
      final produto = produtos[indice];
      if (linha.isEven) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(esquerda, topo + 2, largura, alturaLinha - 4),
            const Radius.circular(12),
          ),
          Paint()..color = _vermelho.withValues(alpha: .045),
        );
      }

      final larguraPreco = math.min(165.0, largura * .34);
      final inicioPreco = esquerda + largura - larguraPreco;
      final fimNome = esquerda + largura * .57;
      _texto(
        canvas,
        produto.nome,
        Rect.fromLTWH(
            esquerda + 12, topo, fimNome - esquerda - 18, alturaLinha),
        tamanho: tamanhoFonte,
        peso: FontWeight.w800,
        cor: _vinho,
        maxLinhas: 1,
      );
      _pontilhado(
        canvas,
        Offset(fimNome, topo + alturaLinha / 2 + 2),
        inicioPreco - 8,
      );
      _texto(
        canvas,
        produto.valorFormatado,
        Rect.fromLTWH(inicioPreco, topo, larguraPreco - 8, alturaLinha),
        tamanho: tamanhoFonte,
        peso: FontWeight.w900,
        cor: _vermelho,
        maxLinhas: 1,
        alinhamento: TextAlign.right,
      );
    }
    canvas.restore();
  }

  static void _pontilhado(Canvas canvas, Offset inicio, double fimX) {
    final tinta = Paint()..color = _vinho.withValues(alpha: .30);
    for (var x = inicio.dx; x < fimX; x += 10) {
      canvas.drawCircle(Offset(x, inicio.dy), 1.8, tinta);
    }
  }

  static void _sombra(
    Canvas canvas,
    RRect area, {
    double deslocamento = 10,
    double opacidade = .18,
  }) {
    canvas.drawRRect(
      area.shift(Offset(0, deslocamento)),
      Paint()
        ..color = Colors.black.withValues(alpha: opacidade)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
  }

  static void _texto(
    Canvas canvas,
    String texto,
    Rect area, {
    required double tamanho,
    required FontWeight peso,
    required Color cor,
    required int maxLinhas,
    TextAlign alinhamento = TextAlign.left,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          color: cor,
          fontSize: tamanho,
          fontWeight: peso,
          height: 1.08,
        ),
      ),
      textAlign: alinhamento,
      textDirection: ui.TextDirection.ltr,
      maxLines: maxLinhas,
      ellipsis: '…',
    )..layout(
        minWidth: alinhamento == TextAlign.left ? 0 : area.width,
        maxWidth: area.width,
      );
    painter.paint(
      canvas,
      Offset(area.left, area.top + ((area.height - painter.height) / 2)),
    );
  }
}
