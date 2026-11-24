import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:dio/dio.dart';

Future<void Function(Map<String, Object?>)> iniciarGravadorDiagnostico({required String projeto, required String diretorio}) async {
  final resposta = ReceivePort();
  await Isolate.spawn(_executarGravador, [resposta.sendPort, projeto, diretorio], debugName: 'diagnosticos');
  final porta = await resposta.first as SendPort;
  resposta.close();
  return porta.send;
}

void _executarGravador(List<Object?> args) {
  final porta = ReceivePort();
  (args[0] as SendPort).send(porta.sendPort);
  final gravador = GravadorDiagnostico(args[1] as String, Directory(args[2] as String));
  Timer? timer;
  timer = Timer.periodic(const Duration(seconds: 2), (_) => unawaited(gravador.processar()));
  porta.listen((dynamic mensagem) {
    if (mensagem is! Map) return;
    final comando = Map<String, Object?>.from(mensagem);
    if (comando['comando'] == 'encerrar') {
      timer?.cancel();
      porta.close();
      unawaited(gravador.fechar());
      return;
    }
    gravador.receber(comando);
  });
}

/// Todo I/O, compressao futura e HTTP desta classe rodam fora da interface.
class GravadorDiagnostico {
  GravadorDiagnostico(this.projeto, this.diretorio, {DateTime Function()? agora}) : agora = agora ?? DateTime.now;
  final String projeto;
  final Directory diretorio;
  final DateTime Function() agora;
  final String instancia = '$pid-${DateTime.now().microsecondsSinceEpoch}';
  final _fila = <Map<String, Object?>>[];
  final _pendentes = <Map<String, Object?>>[];
  Map<String, Object?> _contexto = {};
  String _url = '', _token = '', _escopo = '';
  DateTime? _ultimoPulso;
  DateTime? _proximoEnvio;
  String _diaManutencao = '';
  bool _ativa = true, _travamentoRegistrado = false, _ocupado = false;
  int _parte = 0, _falhasEnvio = 0, _descartados = 0;
  bool _restaurado = false;
  RandomAccessFile? _travaFila;

  File get _arquivoFila => File('${diretorio.path}/fila_$instancia.json');

  Future<void> fechar() async {
    while (_ocupado) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await processar();
    await _travaFila?.close();
    _travaFila = null;
  }

  void receber(Map<String, Object?> comando) {
    switch (comando['comando']) {
      case 'configurar':
        _url = comando['url']?.toString() ?? '';
        _token = comando['token']?.toString() ?? '';
        _escopo = comando['escopo']?.toString() ?? '';
        _proximoEnvio = agora().add(const Duration(seconds: 5));
        break;
      case 'pulso':
        if (_travamentoRegistrado) {
          _adicionarInterno('interface.retomada', 'A interface voltou a responder', {'pausa_ms': agora().difference(_ultimoPulso ?? agora()).inMilliseconds});
        }
        _ultimoPulso = agora();
        _travamentoRegistrado = false;
        _contexto = Map<String, Object?>.from(comando['contexto'] as Map? ?? {});
        break;
      case 'atividade':
        _ativa = comando['ativa'] == true;
        _ultimoPulso = agora();
        _travamentoRegistrado = false;
        break;
      case 'evento':
        if (_fila.length >= 160) {
          _descartados++;
          return;
        }
        final evento = Map<String, Object?>.from(comando['evento'] as Map);
        evento['dispositivo'] = {'sistema': Platform.operatingSystem, 'versao_sistema': Platform.operatingSystemVersion, 'processo': pid, 'dart': Platform.version.split(' ').first};
        _fila.add({'evento': evento, 'escopo': comando['escopo'] ?? ''});
        break;
    }
  }

  void _adicionarInterno(String origem, String mensagem, Map<String, Object?> dados) {
    final data = agora();
    if (_fila.length >= 160) return;
    _fila.add({
      'escopo': _escopo,
      'evento': {
        'id': '$instancia-${data.microsecondsSinceEpoch}-$origem',
        'projeto': projeto,
        'timestamp_local': data.toIso8601String(),
        'timestamp_utc': data.toUtc().toIso8601String(),
        'dia': data.toIso8601String().substring(0, 10),
        'nivel': 'warning',
        'origem': origem,
        'mensagem': mensagem,
        'dados': dados,
        'contexto': _contexto,
      }
    });
  }

  Future<void> processar() async {
    if (_ocupado) return;
    _ocupado = true;
    try {
      await diretorio.create(recursive: true);
      if (_travaFila == null) {
        _travaFila = await File('${_arquivoFila.path}.lock').open(mode: FileMode.append);
        await _travaFila!.lock(FileLock.exclusive);
      }
      if (!_restaurado) await _restaurar();
      final data = agora();
      if (_ativa && _ultimoPulso != null && data.difference(_ultimoPulso!).inSeconds >= 12 && !_travamentoRegistrado) {
        _travamentoRegistrado = true;
        _adicionarInterno('interface.sem_resposta', 'Possivel travamento: interface sem responder ha pelo menos 12 segundos',
            {'ultimo_pulso': _ultimoPulso!.toIso8601String(), 'observacao': 'Atraso detectado pelo gravador independente; nao prova loop.'});
      }
      if (_descartados > 0) {
        _adicionarInterno('diagnostico.limite', 'Fila de diagnostico atingiu o limite', {'eventos_agrupados': _descartados});
        _descartados = 0;
      }
      final lote = List<Map<String, Object?>>.of(_fila);
      _fila.clear();
      for (final item in lote) {
        final evento = item['evento'] as Map;
        var linha = jsonEncode(evento);
        if (utf8.encode(linha).length > 98304) {
          evento.remove('eventos_anteriores');
          evento['conteudo_limitado'] = true;
          linha = jsonEncode(evento);
          if (utf8.encode(linha).length > 98304) {
            evento['dados'] = {'resumo': linha.substring(0, linha.length.clamp(0, 16000))};
            linha = jsonEncode(evento);
          }
        }
        final dia = evento['dia']?.toString() ?? data.toIso8601String().substring(0, 10);
        var arquivo = File('${diretorio.path}/diagnostico_${dia}_${instancia}_$_parte.jsonl');
        if (await arquivo.exists() && await arquivo.length() >= 4 * 1024 * 1024) {
          _parte++;
          arquivo = File('${diretorio.path}/diagnostico_${dia}_${instancia}_$_parte.jsonl');
        }
        await arquivo.writeAsString('$linha\n', mode: FileMode.append);
        if ((item['escopo'] as String).isNotEmpty) _pendentes.add(item);
      }
      if (_pendentes.length > 400) {
        final excesso = _pendentes.length - 400;
        _pendentes.removeRange(0, excesso);
        _adicionarInterno('diagnostico.envio_limitado', 'Envio remoto limitado; detalhes preservados no historico local', {'quantidade': excesso});
      }
      var bytesFila = _pendentes.fold<int>(0, (total, e) => total + utf8.encode(jsonEncode(e)).length);
      var removidos = 0;
      while (bytesFila > 4 * 1024 * 1024 && _pendentes.isNotEmpty) {
        bytesFila -= utf8.encode(jsonEncode(_pendentes.removeAt(0))).length;
        removidos++;
      }
      if (removidos > 0) {
        _adicionarInterno('diagnostico.envio_limitado', 'Fila remota limitada por tamanho; detalhes no historico local', {'quantidade': removidos});
      }
      if (lote.isNotEmpty) await _salvarFila();
      if (_url.isNotEmpty && _token.isNotEmpty && (_proximoEnvio == null || !data.isBefore(_proximoEnvio!))) {
        await _transmitir();
      }
      if (_diaManutencao != data.toIso8601String().substring(0, 10)) {
        await _limpar(data);
        _diaManutencao = data.toIso8601String().substring(0, 10);
      }
    } catch (_) {
      // Nenhum erro daqui volta para o isolate da operacao.
    } finally {
      _ocupado = false;
    }
  }

  Future<void> _restaurar() async {
    _restaurado = true;
    // Nao assumir propriedade de filas de outros processos ainda ativos.
    await for (final entrada in diretorio.list(followLinks: false)) {
      if (entrada is! File || !RegExp(r'[/\\]fila_[0-9]+-[0-9]+\.json(?:\.tmp)?$').hasMatch(entrada.path)) {
        continue;
      }
      final stat = await entrada.stat();
      if (entrada.path == _arquivoFila.path || stat.size > 8 * 1024 * 1024) {
        continue;
      }
      // Filas sao recuperadas somente pelo mesmo projeto/diretorio. Duplicatas
      // apos queda sao removidas no coletor pelo ID, sem repetir operacoes.
      RandomAccessFile? trava;
      try {
        final arquivoBase = entrada.path.replaceFirst(RegExp(r'\.tmp$'), '');
        if (entrada.path.endsWith('.tmp') && await File(arquivoBase).exists()) {
          continue;
        }
        trava = await File('$arquivoBase.lock').open(mode: FileMode.append);
        await trava.lock(FileLock.exclusive);
        final itens = jsonDecode(await entrada.readAsString());
        if (itens is List) {
          _pendentes.addAll(itens.whereType<Map>().take(400).map((v) => Map<String, Object?>.from(v)));
          if (_pendentes.length > 400) {
            _pendentes.removeRange(0, _pendentes.length - 400);
          }
          await _salvarFila();
          await entrada.delete();
        }
      } catch (_) {
        /* Arquivo parcial/em uso continua para a proxima inicializacao. */
      } finally {
        await trava?.close();
      }
    }
  }

  Future<void> _salvarFila() async {
    final temporario = File('${_arquivoFila.path}.tmp');
    await temporario.writeAsString(jsonEncode(_pendentes), flush: true);
    if (await _arquivoFila.exists()) await _arquivoFila.delete();
    await temporario.rename(_arquivoFila.path);
  }

  Future<void> _transmitir() async {
    final escopo = _escopo;
    final itens = <Map<String, Object?>>[];
    var bytes = 0;
    for (final item in _pendentes.where((e) => e['escopo'] == escopo)) {
      final tamanho = utf8.encode(jsonEncode(item['evento'])).length;
      if (itens.isNotEmpty && (bytes + tamanho > 220000 || itens.length >= 12)) {
        break;
      }
      bytes += tamanho;
      itens.add(item);
    }
    _proximoEnvio = agora().add(const Duration(seconds: 30));
    if (itens.isEmpty) return;
    final http = Dio(BaseOptions(connectTimeout: const Duration(seconds: 2), sendTimeout: const Duration(seconds: 3), receiveTimeout: const Duration(seconds: 3), followRedirects: false));
    try {
      final resposta = await http.post<dynamic>(_url, data: {'eventos': itens.map((e) => e['evento']).toList()}, options: Options(headers: {'Authorization': 'Bearer $_token'}));
      if (resposta.data is! Map || resposta.data['sucesso'] != true) {
        throw const FormatException('Sem confirmacao');
      }
      final ids = (resposta.data['ids'] as List?)?.map((e) => e.toString()).toSet() ?? <String>{};
      _pendentes.removeWhere((e) => e['escopo'] == escopo && ids.contains((e['evento'] as Map)['id']));
      await _salvarFila();
      _falhasEnvio = 0;
    } catch (_) {
      _falhasEnvio = (_falhasEnvio + 1).clamp(1, 6);
      _proximoEnvio = agora().add(Duration(seconds: 30 * (1 << _falhasEnvio)));
    } finally {
      http.close(force: true);
    }
  }

  Future<void> _limpar(DateTime data) async {
    final arquivos = <({File arquivo, FileStat stat})>[];
    await for (final entrada in diretorio.list(followLinks: false)) {
      if (entrada is! File || !RegExp(r'[/\\]diagnostico_\d{4}-\d{2}-\d{2}_[\d-]+_\d+\.jsonl$').hasMatch(entrada.path)) {
        continue;
      }
      final stat = await entrada.stat();
      arquivos.add((arquivo: entrada, stat: stat));
    }
    arquivos.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
    var total = arquivos.fold<int>(0, (s, e) => s + e.stat.size);
    for (final item in arquivos) {
      if (data.difference(item.stat.modified).inDays <= 30 && total <= 128 * 1024 * 1024) {
        continue;
      }
      try {
        await item.arquivo.delete();
        total -= item.stat.size;
      } catch (_) {/* Em uso. */}
    }
  }
}
