import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';

import 'armazenamento_diagnostico.dart';
import 'sanitizador_diagnostico.dart';

/// Nunca aguardar este servico no caminho de venda, impressao ou navegacao.
class ServicoDiagnostico with WidgetsBindingObserver {
  ServicoDiagnostico._();
  static final instancia = ServicoDiagnostico._();
  final _anteriores = Queue<Map<String, Object?>>();
  final _inicioPendente = Queue<Map<String, Object?>>();
  final _repeticoes = <String, ({DateTime inicio, int quantidade})>{};
  final _contexto = <String, Object?>{};
  final _frequenciaHttp = <String, ({DateTime inicio, int quantidade})>{};
  final _operacoes = <String, Object?>{};
  void Function(Map<String, Object?>)? _enviar;
  bool _iniciado = false;
  int _sequencia = 0;
  int _enviadosNaJanela = 0;
  int _descartados = 0;
  DateTime _janela = DateTime.now();
  String _projeto = 'sistemarestaurante';
  final String sessao = DateTime.now().microsecondsSinceEpoch.toString();
  String _destino = '';
  Timer? _pulso;

  void inicializar({required String projeto, String versao = '', String? diretorio}) {
    if (_iniciado || kIsWeb) return;
    _iniciado = true;
    _projeto = projeto;
    _contexto['versao'] = versao;
    unawaited(_iniciar(diretorio));
  }

  Future<void> _iniciar(String? diretorio) async {
    try {
      final pasta = diretorio ?? '${(await getApplicationSupportDirectory()).path}/diagnosticos';
      _enviar = await iniciarGravadorDiagnostico(projeto: _projeto, diretorio: pasta);
      while (_inicioPendente.isNotEmpty) {
        _enviar!(_inicioPendente.removeFirst());
      }
      WidgetsBinding.instance.addObserver(this);
      _pulso = Timer.periodic(const Duration(seconds: 2), (_) {
        _enviar?.call({
          'comando': 'pulso',
          'contexto': SanitizadorDiagnostico.mapa({
            ..._contexto,
            'ultimos_eventos': _anteriores.toList().reversed.take(5).toList(),
          })
        });
        _resumirRepeticoes();
      });
      didChangeAppLifecycleState(WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed);
    } catch (_) {
      // Falta de plugin, permissao ou disco nao impede a operacao.
      _inicioPendente.clear();
    }
  }

  void atualizarContexto(Map<String, Object?> contexto) {
    try {
      _contexto.addAll(SanitizadorDiagnostico.mapa(contexto));
    } catch (_) {/* Diagnostico e opcional. */}
  }

  /// Credenciais permanecem apenas em memoria e nunca entram no evento.
  void configurarEnvio({required String url, required String token, required String empresa, required String usuario}) {
    if (token.isEmpty || empresa.isEmpty || usuario.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https'].contains(uri.scheme) || uri.userInfo.isNotEmpty) {
      return;
    }
    final destino = '${uri.replace(query: '', fragment: '')}|$empresa';
    if (_destino != destino) {
      _anteriores.clear();
      _operacoes.clear();
      _repeticoes.clear();
    }
    _destino = destino;
    atualizarContexto({'empresa': empresa, 'usuario_id': usuario});
    _mandar({'comando': 'configurar', 'url': url, 'token': token, 'escopo': _destino});
  }

  void encerrarEnvio() {
    _destino = '';
    _anteriores.clear();
    _operacoes.clear();
    _repeticoes.clear();
    _contexto.remove('empresa');
    _contexto.remove('usuario_id');
    _mandar({'comando': 'configurar', 'url': '', 'token': '', 'escopo': ''});
  }

  void contexto({required String origem, required String mensagem, Map<String, Object?> dados = const {}}) {
    try {
      _adicionarContexto(origem, mensagem, dados);
    } catch (_) {/* Nunca interromper operacoes. */}
  }

  void _adicionarContexto(String origem, String mensagem, Map<String, Object?> dados) {
    _anteriores.add({'hora': DateTime.now().toIso8601String(), 'origem': origem, 'mensagem': mensagem, 'dados': SanitizadorDiagnostico.limpar(dados)});
    while (_anteriores.length > 18) {
      _anteriores.removeFirst();
    }
  }

  void lembrarOperacao(String id, Map<String, Object?> dados) {
    try {
      if (!_iniciado) return;
      if (_operacoes.length >= 40) _operacoes.remove(_operacoes.keys.first);
      _operacoes[id] = SanitizadorDiagnostico.limpar(dados);
    } catch (_) {/* Conservar a operacao ja gravada. */}
  }

  Object? contextoOperacao(String id) => _operacoes[id];

  void registrar({required String origem, required String mensagem, String nivel = 'error', StackTrace? pilha, Map<String, Object?> dados = const {}}) {
    try {
      _registrar(origem: origem, mensagem: mensagem, nivel: nivel, pilha: pilha, dados: dados);
    } catch (_) {/* Nao propagar falhas do diagnostico. */}
  }

  void _registrar({required String origem, required String mensagem, required String nivel, StackTrace? pilha, required Map<String, Object?> dados}) {
    if (!_iniciado) return;
    final agora = DateTime.now();
    if (agora.difference(_janela).inSeconds >= 60) {
      final omitidos = _descartados;
      _enviadosNaJanela = 0;
      _descartados = 0;
      _janela = agora;
      if (omitidos > 0) {
        _gravar('diagnostico.limite', 'Eventos agrupados por excesso de volume', 'warning', {'quantidade': omitidos}, null);
      }
    }
    // Limite antes de copiar payload/pilha: um loop nao pode lotar o SendPort.
    final requisicao = dados['requisicao'];
    final assinatura = requisicao == null ? '${dados['id_operacao'] ?? dados['id_requisicao'] ?? dados['pedido_id'] ?? ''}' : jsonEncode(SanitizadorDiagnostico.limpar(requisicao, 0, [100, 4000])).hashCode.toString();
    final chave = '$origem|${mensagem.length > 180 ? mensagem.substring(0, 180) : mensagem}|$assinatura';
    final anterior = _repeticoes[chave];
    if (anterior != null && agora.difference(anterior.inicio).inSeconds < 60) {
      _repeticoes[chave] = (inicio: anterior.inicio, quantidade: anterior.quantidade + 1);
      if (anterior.quantidade == 19) {
        _gravar('diagnostico.possivel_loop', 'Falha repetida pelo menos 20 vezes: $origem', 'warning', {'falha': mensagem, 'primeira_ocorrencia': anterior.inicio.toIso8601String(), 'observacao': 'Repeticao detectada; nao confirma loop.'},
            null);
      }
      return;
    }
    if (_enviadosNaJanela >= 120) {
      _descartados++;
      return;
    }
    if (_repeticoes.length >= 200) _repeticoes.remove(_repeticoes.keys.first);
    _repeticoes[chave] = (inicio: agora, quantidade: 0);
    _enviadosNaJanela++;
    _gravar(origem, mensagem, nivel, dados, pilha);
  }

  void _resumirRepeticoes() {
    final agora = DateTime.now();
    for (final e in _repeticoes.entries.toList()) {
      if (agora.difference(e.value.inicio).inSeconds < 60) continue;
      _repeticoes.remove(e.key);
      if (e.value.quantidade > 0) {
        _gravar(
            'diagnostico.repeticao',
            'Falha repetida: ${e.key}',
            'warning',
            {
              'repeticoes_adicionais': e.value.quantidade,
              'primeira_ocorrencia': e.value.inicio.toIso8601String(),
              'possivel_loop': e.value.quantidade >= 20,
            },
            null);
      }
    }
  }

  void _gravar(String origem, String mensagem, String nivel, Map<String, Object?> dados, StackTrace? pilha) {
    final agora = DateTime.now();
    final evento = SanitizadorDiagnostico.mapa({
      'id': '$_projeto-$sessao-${++_sequencia}',
      'projeto': _projeto,
      'sessao': sessao,
      'timestamp_local': agora.toIso8601String(),
      'timestamp_utc': agora.toUtc().toIso8601String(),
      'dia': agora.toIso8601String().substring(0, 10),
      'nivel': nivel,
      'origem': origem,
      'mensagem': mensagem,
      'contexto': Map.of(_contexto),
      if (pilha != null) 'pilha': pilha.toString(),
      'dados': dados,
      'eventos_anteriores': _anteriores.toList(),
    });
    _mandar({'comando': 'evento', 'evento': evento, 'escopo': _destino});
  }

  void _mandar(Map<String, Object?> comando) {
    if (_enviar != null) {
      _enviar!(comando);
      return;
    }
    if (_inicioPendente.length < 40) _inicioPendente.add(comando);
  }

  void console(String texto) {
    if (texto.startsWith('[observabilidade]') || texto.startsWith('[Erro recuperavel]')) {
      return;
    }
    final classificar = texto.replaceAll(RegExp(r'\bErro:\s*Nenhum\s*$', caseSensitive: false), '');
    if (RegExp(r'\b(erro|error|exception|falha|failed|fatal|timeout)\b', caseSensitive: false).hasMatch(classificar)) {
      registrar(origem: 'console', mensagem: texto, nivel: 'warning');
    }
  }

  void iniciarRequisicao(RequestOptions options) {
    try {
      _iniciarRequisicao(options);
    } catch (_) {/* Conservar o fluxo HTTP. */}
  }

  void _iniciarRequisicao(RequestOptions options) {
    if (options.path.contains('/diagnosticos/') || options.path.startsWith('diagnosticos/')) {
      return;
    }
    options.extra['diagnostico_inicio'] = DateTime.now().millisecondsSinceEpoch;
    final agora = DateTime.now();
    final caminho = '${options.method} ${options.uri.path}';
    final janela = _frequenciaHttp[caminho];
    if (janela == null || agora.difference(janela.inicio).inSeconds >= 10) {
      if (_frequenciaHttp.length > 150) {
        _frequenciaHttp.remove(_frequenciaHttp.keys.first);
      }
      _frequenciaHttp[caminho] = (inicio: agora, quantidade: 1);
    } else {
      final quantidade = janela.quantidade + 1;
      _frequenciaHttp[caminho] = (inicio: janela.inicio, quantidade: quantidade);
      if (quantidade == 50) {
        registrar(origem: 'http.possivel_loop', mensagem: 'Requisições em excesso: $caminho', nivel: 'warning', dados: {'quantidade': quantidade, 'janela_segundos': 10, 'observacao': 'Alerta de frequencia; nao confirma loop.'});
      }
    }
    options.headers.putIfAbsent('X-Correlation-Id', () => '$sessao-${++_sequencia}');
    contexto(origem: 'http.request', mensagem: '${options.method} ${options.path}', dados: {
      'correlacao': options.headers['X-Correlation-Id'] ?? options.headers['x-correlation-id'],
      'campos': _campos(options.data),
      'parametros': options.queryParameters,
    });
  }

  void resposta(Response response) {
    try {
      _resposta(response);
    } catch (_) {/* Conservar a resposta original. */}
  }

  void _resposta(Response response) {
    final options = response.requestOptions;
    if (options.path.contains('diagnosticos/')) return;
    final corpo = _campos(response.data);
    final falhaPhp = corpo is String && RegExp(r'Fatal error|Parse error|SQLSTATE\[|PDOException|Uncaught\s+\w*(?:Error|Exception)|Warning:\s', caseSensitive: false).hasMatch(corpo);
    final falhou = falhaPhp ||
        (corpo is Map &&
            (corpo['sucesso'] == false ||
                corpo['sucesso'] == 'false' ||
                corpo['success'] == false ||
                (corpo['erro'] != null && corpo['erro'] != false && corpo['erro'] != '') ||
                (corpo['error'] != null && corpo['error'] != false && corpo['error'] != '') ||
                corpo['status'] == 'erro'));
    final duracao = DateTime.now().millisecondsSinceEpoch - ((options.extra['diagnostico_inicio'] as int?) ?? DateTime.now().millisecondsSinceEpoch);
    if (falhou || (response.statusCode ?? 0) >= 400 || duracao >= 8000) {
      registrar(
          origem: falhou ? 'http.contrato' : 'http.resposta',
          mensagem: '${options.method} ${options.path}',
          nivel: falhou || (response.statusCode ?? 0) >= 400 ? 'error' : 'warning',
          dados: _dadosHttp(options, response.statusCode, corpo, duracao));
    } else {
      contexto(origem: 'http.response', mensagem: '${options.method} ${options.path}', dados: {
        'status': response.statusCode,
        'duracao_ms': duracao,
        'resumo': _resumo(corpo),
      });
    }
  }

  void erroHttp(DioException erro) {
    try {
      _erroHttp(erro);
    } catch (_) {/* Conservar a falha original. */}
  }

  void _erroHttp(DioException erro) {
    if (erro.type == DioExceptionType.cancel || erro.requestOptions.path.contains('diagnosticos/')) {
      return;
    }
    final options = erro.requestOptions;
    final duracao = DateTime.now().millisecondsSinceEpoch - ((options.extra['diagnostico_inicio'] as int?) ?? DateTime.now().millisecondsSinceEpoch);
    registrar(
        origem: 'http.${erro.type.name}',
        mensagem: '${options.method} ${options.path}',
        pilha: erro.stackTrace,
        dados: {..._dadosHttp(options, erro.response?.statusCode, _campos(erro.response?.data), duracao), 'erro': erro.message, 'causa': erro.error?.toString()});
  }

  Map<String, Object?> _dadosHttp(RequestOptions o, int? status, Object? corpo, int duracao) => {
        'metodo': o.method,
        'url': o.uri.replace(userInfo: '', query: '', fragment: '').toString(),
        'correlacao': o.headers['x-correlation-id'] ?? o.headers['X-Correlation-Id'],
        'status': status,
        'duracao_ms': duracao,
        'empresa': o.headers['x-audit-company-id'],
        'usuario_id': o.headers['x-audit-user-id'],
        'requisicao': _campos(o.data),
        'parametros': o.queryParameters,
        'resposta': corpo,
        'prazos_ms': {'conexao': o.connectTimeout?.inMilliseconds, 'envio': o.sendTimeout?.inMilliseconds, 'resposta': o.receiveTimeout?.inMilliseconds},
      };

  static Object? _campos(Object? data) {
    if (data is FormData) {
      return {'campos': Map.fromEntries(data.fields), 'arquivos_quantidade': data.files.length};
    }
    if (data is String && data.length <= 65536) {
      try {
        return jsonDecode(data);
      } on FormatException {
        return data;
      }
    }
    return data;
  }

  static Object? _resumo(Object? data) => data is List
      ? {'quantidade': data.length}
      : data is Map
          ? {'campos': data.keys.take(30).toList(), if (data['resultado'] is List) 'quantidade': (data['resultado'] as List).length}
          : data?.runtimeType.toString();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _mandar({'comando': 'atividade', 'ativa': state == AppLifecycleState.resumed});
  }

  @visibleForTesting
  void usarEmissorParaTeste(void Function(Map<String, Object?>) emissor) {
    _iniciado = true;
    _enviar = emissor;
    _repeticoes.clear();
    _anteriores.clear();
    _frequenciaHttp.clear();
    _enviadosNaJanela = 0;
    _descartados = 0;
    _janela = DateTime.now();
  }

  @visibleForTesting
  void finalizarParaTeste() {
    _pulso?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _enviar?.call({'comando': 'encerrar'});
    _enviar = null;
    _iniciado = false;
  }
}

class ObservadorDiagnostico extends NavigatorObserver {
  void _registrar(Route<dynamic>? rota) {
    final nome = rota?.settings.name ?? rota?.runtimeType.toString() ?? 'inicio';
    ServicoDiagnostico.instancia.atualizarContexto({'rota': nome});
    ServicoDiagnostico.instancia.contexto(origem: 'navegacao', mensagem: nome);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _registrar(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _registrar(previousRoute);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _registrar(newRoute);
  }
}
