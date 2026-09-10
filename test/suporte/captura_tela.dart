import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> carregarFontesDeTeste() async {
  const fonte = String.fromEnvironment('FONTE_TESTE');
  if (fonte.isEmpty) return;
  final loader = FontLoader('Roboto')
    ..addFont(File(fonte).readAsBytes().then(ByteData.sublistView));
  await loader.load();
  final icones = FontLoader('MaterialIcons')
    ..addFont(File('${File(fonte).parent.path}/MaterialIcons-Regular.otf')
        .readAsBytes()
        .then(ByteData.sublistView));
  await icones.load();
}

Future<void> capturarTela(WidgetTester tester, String nome) async {
  if (!const bool.fromEnvironment('CAPTURAR_TELAS')) return;
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('captura')));
  await tester.runAsync(() async {
    final imagem = await boundary.toImage(pixelRatio: 1);
    final bytes = await imagem.toByteData(format: ui.ImageByteFormat.png);
    final pasta = Directory('build/validacao_ui')..createSync(recursive: true);
    File('${pasta.path}/$nome.png')
        .writeAsBytesSync(bytes!.buffer.asUint8List());
    imagem.dispose();
  });
}
