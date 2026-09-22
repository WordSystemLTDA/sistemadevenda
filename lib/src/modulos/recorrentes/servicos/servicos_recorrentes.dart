import 'dart:convert';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import '../modelos/modelo_recorrente.dart';

class ServicosRecorrentes {
  final DioCliente dio;
  final UsuarioProvedor usuario;
  ServicosRecorrentes(this.dio, this.usuario);

  static String novaChave() =>
      '${DateTime.now().microsecondsSinceEpoch}-${List.generate(16, (_) => Random.secure().nextInt(16).toRadixString(16)).join()}';

  Future<dynamic> _requisicao(String acao, Map<String, dynamic> campos,
      {bool leitura = false}) async {
    final sessao = usuario.usuario;
    if (sessao == null) throw StateError('Entre novamente no sistema.');
    final dados = {
      ...campos,
      'empresa': sessao.empresa,
      'id_usuario': sessao.id,
      if (leitura) '_atualizacao': DateTime.now().microsecondsSinceEpoch,
    };
    try {
      final opcoes = Options(extra: {'semCache': true});
      final resposta = leitura
          ? await dio.cliente.get('recorrentes/$acao.php',
              queryParameters: dados, options: opcoes)
          : await dio.cliente
              .post('recorrentes/$acao.php', data: dados, options: opcoes);
      final json = resposta.data is String
          ? jsonDecode(resposta.data as String)
          : resposta.data;
      if (json is! Map || json['sucesso'] != true) {
        throw StateError(json is Map
            ? '${json['mensagem'] ?? 'Não foi possível concluir.'}'
            : 'Resposta inválida da agenda.');
      }
      return json['dados'];
    } on DioException catch (e) {
      final dados = e.response?.data;
      throw StateError(dados is Map && dados['mensagem'] != null
          ? '${dados['mensagem']}'
          : 'Não foi possível acessar os recorrentes. Verifique a conexão e a atualização da API.');
    }
  }

  Future<List<ModeloRecorrente>> listar(DateTime inicio, DateTime fim,
      {bool cadastros = false}) async {
    final dados = await _requisicao(
        'listar',
        {
          'inicio': DateFormat('yyyy-MM-dd').format(inicio),
          'fim': DateFormat('yyyy-MM-dd').format(fim),
          'cadastros': cadastros ? 'Sim' : 'Não'
        },
        leitura: true);
    return (dados as List)
        .map((r) =>
            ModeloRecorrente.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<String> inserir(
      {required String chave,
      required String cliente,
      required String endereco,
      required String tipoEntrega,
      required String observacao,
      required ConfiguracaoRecorrencia configuracao}) async {
    final dados = await _requisicao('inserir', {
      'chave': chave,
      'cliente': cliente,
      'endereco': endereco,
      'tipoentrega': tipoEntrega,
      'obs': observacao,
      'recorrencia': configuracao.toMap()
    });
    return _idDelivery(dados);
  }

  Future<String> abrir(ModeloRecorrente item) async {
    final dados = await _requisicao('gerar',
        {'id': item.id, 'data': DateFormat('yyyy-MM-dd').format(item.data)});
    return _idDelivery(dados);
  }

  Future<PagamentoRecorrente?> pagamento(String idDelivery) async {
    final dados = await _requisicao('pagamento', {'id_delivery': idDelivery},
        leitura: true);
    if (dados is! Map || dados['recorrente'] != true) return null;
    return PagamentoRecorrente.fromMap(Map<String, dynamic>.from(dados));
  }

  String _idDelivery(dynamic dados) {
    final id = dados is Map ? '${dados['idDelivery'] ?? ''}' : '';
    if ((int.tryParse(id) ?? 0) <= 0) {
      throw StateError(
          'Pedido sem identificação. Atualize a agenda antes de continuar.');
    }
    return id;
  }

  Future<void> pular(ModeloRecorrente item) async => _requisicao('pular',
      {'id': item.id, 'data': DateFormat('yyyy-MM-dd').format(item.data)});
  Future<void> restaurar(ModeloRecorrente item) async => _requisicao(
      'restaurar',
      {'id': item.id, 'data': DateFormat('yyyy-MM-dd').format(item.data)});
  Future<void> editar(ModeloRecorrente item,
          ConfiguracaoRecorrencia configuracao, bool ativo) async =>
      _requisicao('editar', {
        'id': item.id,
        ...configuracao.toMap(),
        'ativo': ativo ? 'Sim' : 'Não'
      });

  Future<void> excluir(ModeloRecorrente item) async =>
      _requisicao('excluir', {'id': item.id});
}
