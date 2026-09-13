import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:dio/dio.dart';

import 'pedido_falado.dart';

class ServicoPedidoVoz {
  final String servidor;
  final UsuarioProvedor usuario;
  late final _identidade = usuario.usuario;
  String? _token;
  late final Dio _voz = Dio(BaseOptions(
      baseUrl: enderecoSeguro(servidor),
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 90)));
  late final DioCliente _catalogo = DioCliente(servidor: servidor)
    ..cliente.options.extra['semCache'] = true;
  final _cancelamento = CancelToken();
  ServicoPedidoVoz({required this.servidor, required this.usuario}) {
    // Capture agora; nao herdar uma conta trocada durante a gravacao.
    _identidade;
  }

  static String enderecoSeguro(String servidor) {
    final uri = Uri.parse(servidor);
    if (!['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      throw const FalhaPedidoVoz('Endereço do servidor inválido.');
    }
    return uri
        .replace(scheme: 'https', port: uri.scheme == 'https' ? uri.port : 443)
        .toString();
  }

  void _validar() {
    if (_cancelamento.isCancelled || !identical(usuario.usuario, _identidade)) {
      throw const FalhaPedidoVoz(
          'A sessão mudou. Abra novamente o atendimento.');
    }
    if (_identidade?.senha?.isNotEmpty != true) {
      throw const FalhaPedidoVoz(
          'Entre novamente no aplicativo para habilitar os pedidos por voz.');
    }
  }

  Future<Map> _requisicao({FormData? audio}) async {
    _validar();
    try {
      final opcoes = Options(headers: {'X-Garcom-Voz': _token});
      final resposta = audio == null
          ? await _voz.get('voz/pedido.php',
              options: opcoes, cancelToken: _cancelamento)
          : await _voz.post('voz/pedido.php',
              data: audio, options: opcoes, cancelToken: _cancelamento);
      _validar();
      if (resposta.data is! Map ||
          resposta.data['sucesso'] != true ||
          resposta.data['protocolo'] != 1) {
        throw const FalhaPedidoVoz(
            'Atualize a API do servidor para usar pedidos por voz.');
      }
      return resposta.data as Map;
    } on DioException catch (erro) {
      final dados = erro.response?.data;
      if (dados is Map &&
          dados['mensagem'] is String &&
          (dados['mensagem'] as String).length < 600) {
        throw FalhaPedidoVoz(dados['mensagem'] as String);
      }
      throw const FalhaPedidoVoz(
          'Não consegui conectar ao serviço de voz. Nenhum pedido foi enviado.');
    }
  }

  Future<void> verificar() async {
    _validar();
    try {
      final resposta = await _voz.post('voz/sessao.php',
          data: {
            'empresa': _identidade!.empresa,
            'id_usuario': _identidade!.id,
            'senha': _identidade!.senha,
          },
          cancelToken: _cancelamento);
      _validar();
      if (resposta.data is! Map || resposta.data['token'] is! String) {
        throw const FalhaPedidoVoz(
            'Atualize e configure a API de voz no servidor.');
      }
      _token = resposta.data['token'] as String;
    } on DioException {
      throw const FalhaPedidoVoz(
          'Voz indisponível. Configure HTTPS e a chave da API da OpenAI no servidor. A assinatura do ChatGPT não ativa esta integração.');
    }
    await _requisicao();
  }

  Future<({String texto, Modelowordprodutos item})> interpretar(
      String caminho) async {
    final resposta = await _requisicao(
        audio: FormData.fromMap({
      'audio': await MultipartFile.fromFile(caminho, filename: 'pedido.m4a'),
    }));
    if (resposta['pedido'] is! Map) {
      throw const FalhaPedidoVoz(
          'Não foi possível entender o pedido completo.');
    }
    final pedido = PedidoFalado.fromMap(resposta['pedido']);
    final produtos = ServicoProduto(_catalogo, usuario);
    final categorias = ServicosCategoria(_catalogo, usuario);
    final listaCategorias = await categorias.listar();
    _validar();
    final config = await ServicoConfigBigchef(_catalogo, usuario).listar();
    _validar();
    final lista = <String, Modelowordprodutos>{};
    // Consulta completa: a categoria visivel nao limita os sabores da voz.
    for (var pagina = 1;; pagina++) {
      final encontrados = await produtos.listarPorCategoria('0', pagina);
      _validar();
      final antes = lista.length;
      for (final item in encontrados) {
        lista[item.id] = item;
      }
      if (encontrados.length < 15) break;
      if (lista.length == antes || pagina >= 200) {
        throw const FalhaPedidoVoz(
            'Não consegui consultar o cardápio completo. Use a seleção manual.');
      }
    }
    if (config == null) {
      throw const FalhaPedidoVoz('Configuração do cardápio indisponível.');
    }
    final montador = MontadorPedidoVoz(
        usuario: usuario,
        servicoCategorias: categorias,
        configuracao: config,
        categorias: listaCategorias,
        catalogo: lista.values.toList());
    final principal = montador.produtosDoPedido(pedido).first;
    final detalhes =
        await produtos.listarPorId(principal.id, montador.idTamanho(pedido));
    _validar();
    if (detalhes == null) {
      throw const FalhaPedidoVoz('O produto não está mais disponível.');
    }
    return (
      texto: resposta['texto'] as String? ?? '',
      item: montador.montar(pedido, detalhes)
    );
  }

  void dispose() {
    _cancelamento.cancel();
    _voz.close(force: true);
    _catalogo.cliente.close(force: true);
  }
}
