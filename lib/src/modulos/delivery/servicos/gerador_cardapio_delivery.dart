import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Gera uma imagem leve e pronta para envio no WhatsApp, sem depender de
/// captura de tela ou de um widget visivel.
class GeradorCardapioDelivery {
  static const double _largura = 1080;
  static const double _altura = 1350;

  static Future<Uint8List> gerar({
    required String nomeEmpresa,
    required List<String> ingredientes,
    DateTime? data,
  }) async {
    final itens = ingredientes
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toSet()
        .toList();
    if (itens.isEmpty) {
      throw StateError('Não há ingredientes configurados para hoje.');
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const tamanho = Size(_largura, _altura);
    final fundo = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff8f0909), Color(0xffc51b13), Color(0xff730303)],
      ).createShader(Offset.zero & tamanho);
    canvas.drawRect(Offset.zero & tamanho, fundo);

    final decoracao = Paint()..color = Colors.white.withValues(alpha: .09);
    canvas.drawCircle(const Offset(70, 180), 190, decoracao);
    canvas.drawCircle(const Offset(1040, 1060), 270, decoracao);

    final cabecalho = RRect.fromRectAndRadius(
      const Rect.fromLTWH(70, 64, 940, 225),
      const Radius.circular(42),
    );
    canvas.drawRRect(cabecalho, Paint()..color = const Color(0xfffff7e9));
    canvas.drawRRect(
      cabecalho,
      Paint()
        ..color = const Color(0xff3e0b0b)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7,
    );

    _texto(
      canvas,
      nomeEmpresa.trim().isEmpty ? 'RESTAURANTE' : nomeEmpresa.trim(),
      const Rect.fromLTWH(120, 104, 840, 66),
      tamanho: 47,
      peso: FontWeight.w800,
      cor: const Color(0xff2d1712),
      maxLinhas: 1,
      alinhamento: TextAlign.center,
    );
    _texto(
      canvas,
      DateFormat('dd/MM/yyyy').format(data ?? DateTime.now()),
      const Rect.fromLTWH(120, 181, 840, 47),
      tamanho: 31,
      peso: FontWeight.w600,
      cor: const Color(0xff8f0909),
      maxLinhas: 1,
      alinhamento: TextAlign.center,
    );

    final faixa = RRect.fromRectAndRadius(
      const Rect.fromLTWH(45, 325, 990, 145),
      const Radius.circular(24),
    );
    canvas.drawRRect(faixa, Paint()..color = const Color(0xfffff2dc));
    _texto(
      canvas,
      'CARDÁPIO DO DIA',
      const Rect.fromLTWH(90, 357, 900, 83),
      tamanho: 65,
      peso: FontWeight.w900,
      cor: const Color(0xffa50909),
      maxLinhas: 1,
      alinhamento: TextAlign.center,
    );

    const topoLista = 520.0;
    const fimLista = 1140.0;
    final colunas = itens.length > 22 ? 3 : (itens.length > 9 ? 2 : 1);
    final linhas = (itens.length / colunas).ceil();
    final alturaLinha = ((fimLista - topoLista) / linhas).clamp(28.0, 84.0);
    final tamanhoFonte = (alturaLinha * .57).clamp(18.0, 48.0);
    const margem = 80.0;
    const espacoColunas = 30.0;
    final larguraColuna =
        (_largura - (margem * 2) - (espacoColunas * (colunas - 1))) / colunas;

    canvas.save();
    canvas.clipRect(const Rect.fromLTRB(60, topoLista, 1020, fimLista));
    for (var indice = 0; indice < itens.length; indice++) {
      final coluna = indice ~/ linhas;
      final linha = indice % linhas;
      final esquerda = margem + coluna * (larguraColuna + espacoColunas);
      final topo = topoLista + linha * alturaLinha;
      _texto(
        canvas,
        '• ${itens[indice]}',
        Rect.fromLTWH(esquerda, topo, larguraColuna, alturaLinha),
        tamanho: tamanhoFonte,
        peso: FontWeight.w800,
        cor: Colors.white,
        maxLinhas: colunas == 3 ? 1 : 2,
      );
    }
    canvas.restore();

    final rodape = RRect.fromRectAndRadius(
      const Rect.fromLTWH(120, 1200, 840, 92),
      const Radius.circular(46),
    );
    canvas.drawRRect(rodape, Paint()..color = const Color(0xfffff7e9));
    _texto(
      canvas,
      'Faça seu pedido pelo WhatsApp',
      const Rect.fromLTWH(160, 1222, 760, 50),
      tamanho: 34,
      peso: FontWeight.w800,
      cor: const Color(0xff8f0909),
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
        minWidth: alinhamento == TextAlign.center ? area.width : 0,
        maxWidth: area.width,
      );
    painter.paint(
      canvas,
      Offset(area.left, area.top + ((area.height - painter.height) / 2)),
    );
  }
}
