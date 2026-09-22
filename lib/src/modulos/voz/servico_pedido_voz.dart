import 'dart:convert';
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:dio/dio.dart';

import 'pedido_falado.dart';
import 'abertura_falada.dart';
import 'lote_pedido_voz.dart';

class ServicoPedidoVoz {
  final String servidor;
  final UsuarioProvedor usuario;
  late final _identidade = usuario.usuario;
  String? _token;
  Map capacidades = const {};
  int get _timeoutProcessamento =>
      (int.tryParse('${capacidades['timeout_segundos']}') ?? 180)
          .clamp(30, 300);
  bool get suportaLote =>
      capacidades['protocolo'] == 2 || capacidades['protocolo2'] == 1;
  Dio? _clienteVoz;
  DioCliente? _clienteCatalogo;
  Dio get _voz => _clienteVoz ??= Dio(BaseOptions(
      baseUrl: enderecoSeguro(servidor),
      connectTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 90)));
  DioCliente get _catalogo =>
      _clienteCatalogo ??= (DioCliente(servidor: servidor)
        ..cliente.options.extra['semCache'] = true);
  final _cancelamento = CancelToken();
  ServicoPedidoVoz(
      {required this.servidor, required this.usuario, Dio? clienteVoz})
      : _clienteVoz = clienteVoz {
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
    if (uri.scheme == 'http' && _hostLocal(uri.host)) return uri.toString();
    return uri
        .replace(scheme: 'https', port: uri.scheme == 'https' ? uri.port : 443)
        .toString();
  }

  static bool _hostLocal(String host) {
    if (host == 'localhost' || host == '::1' || host == '[::1]') return true;
    final partes = host.split('.');
    if (partes.length != 4 ||
        partes.any((parte) => !RegExp(r'^(0|[1-9]\d{0,2})$').hasMatch(parte))) {
      return false;
    }
    final ip = partes.map(int.parse).toList();
    if (ip.any((parte) => parte > 255)) return false;
    return ip[0] == 10 ||
        ip[0] == 127 ||
        (ip[0] == 172 && ip[1] >= 16 && ip[1] <= 31) ||
        (ip[0] == 192 && ip[1] == 168);
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
      final opcoes = Options(
          headers: {'X-Garcom-Voz': _token},
          receiveTimeout: Duration(
              seconds: audio == null ? 12 : _timeoutProcessamento * 2 + 20));
      final resposta = audio == null
          ? await _voz.get('voz/pedido.php',
              options: opcoes, cancelToken: _cancelamento)
          : await _voz.post('voz/pedido.php',
              data: audio, options: opcoes, cancelToken: _cancelamento);
      _validar();
      if (resposta.data is! Map ||
          resposta.data['sucesso'] != true ||
          ![1, 2].contains(resposta.data['protocolo'])) {
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

  Future<void> verificar({TipoAberturaVoz? abertura}) async {
    _validar();
    try {
      final resposta = await _voz.post('voz/sessao.php',
          options: Options(receiveTimeout: const Duration(seconds: 12)),
          data: {
            'empresa': _identidade!.empresa,
            'id_usuario': _identidade!.id,
            'senha': _identidade!.senha,
          },
          cancelToken: _cancelamento);
      _validar();
      if (resposta.data is! Map ||
          resposta.data['sucesso'] != true ||
          ![1, 2].contains(resposta.data['protocolo']) ||
          resposta.data['token'] is! String ||
          (resposta.data['token'] as String).isEmpty) {
        throw const FalhaPedidoVoz(
            'Atualize e configure a API de voz no servidor.');
      }
      _token = resposta.data['token'] as String;
    } on DioException catch (erro) {
      final dados = erro.response?.data;
      if (dados is Map &&
          dados['mensagem'] is String &&
          (dados['mensagem'] as String).isNotEmpty &&
          (dados['mensagem'] as String).length < 600) {
        throw FalhaPedidoVoz(dados['mensagem'] as String);
      }
      throw const FalhaPedidoVoz(
          'Não consegui conectar ao serviço de voz. Verifique o endereço, a rede e o HTTPS para acesso online.');
    }
    capacidades = await _requisicao();
    if (abertura != null && capacidades['abertura_voz'] != 1) {
      throw const FalhaPedidoVoz(
          'Atualize a API do servidor para abrir mesas e comandas por voz.');
    }
    if (abertura == null && !suportaLote && capacidades['destino_voz'] != 1) {
      throw const FalhaPedidoVoz(
          'Atualize a API de voz para escolher entre carrinho e cozinha. Nenhum pedido foi enviado.');
    }
  }

  Future<LotePedidoVoz> interpretarLote(
      {String? caminho,
      String? texto,
      Map<String, dynamic>? rascunho,
      Map<String, dynamic>? contexto}) async {
    if (!suportaLote) {
      throw const FalhaPedidoVoz(
          'Atualize a API para usar a comanda eletrônica e por voz.');
    }
    final resposta = await _requisicao(
        audio: FormData.fromMap({
      'protocolo': '2',
      'finalidade': 'pedido',
      'destino_voz': '1',
      if (caminho != null)
        'audio': await MultipartFile.fromFile(caminho, filename: 'pedido.wav'),
      if (texto != null) 'texto': texto,
      if (rascunho != null) 'rascunho': jsonEncode(rascunho),
      if (contexto != null) 'contexto': jsonEncode(contexto),
    }));
    if (resposta['protocolo'] != 2 || resposta['pedido'] is! Map) {
      throw const FalhaPedidoVoz(
          'A API não retornou o pedido completo. Atualize o servidor.');
    }
    final pedidoResposta = resposta['pedido'] as Map;
    final pergunta = pedidoResposta['esclarecimento'];
    if (pergunta is String &&
        pergunta.trim().isNotEmpty &&
        pergunta.length <= 500) {
      throw EsclarecimentoPedidoVoz(
          pergunta.trim(), resposta['texto'] as String? ?? texto ?? '');
    }
    final pedidos = LotePedidoVoz.lerPedidos(pedidoResposta);
    final produtos = ServicoProduto(_catalogo, usuario);
    final categorias = ServicosCategoria(_catalogo, usuario);
    final listaCategorias = await categorias.listar();
    _validar();
    final config = await ServicoConfigBigchef(_catalogo, usuario).listar();
    _validar();
    if (config == null) {
      throw const FalhaPedidoVoz('Configuração do cardápio indisponível.');
    }
    final catalogo = <String, Modelowordprodutos>{};
    for (var pagina = 1;; pagina++) {
      final encontrados = await produtos.listarPorCategoria('0', pagina);
      _validar();
      final antes = catalogo.length;
      for (final item in encontrados) {
        catalogo[item.id] = item;
      }
      if (encontrados.length < 15) break;
      if (antes == catalogo.length || pagina >= 200) {
        throw const FalhaPedidoVoz(
            'Não consegui consultar o cardápio completo. Tente novamente.');
      }
    }
    final montador = MontadorPedidoVoz(
        usuario: usuario,
        servicoCategorias: categorias,
        configuracao: config,
        categorias: listaCategorias,
        catalogo: catalogo.values.toList());
    final itens = <Modelowordprodutos>[];
    for (final pedido in pedidos) {
      final principal = montador.produtosDoPedido(pedido).first;
      final detalhes =
          await produtos.listarPorId(principal.id, montador.idTamanho(pedido));
      _validar();
      if (detalhes == null) {
        throw FalhaPedidoVoz('${principal.nome} não está mais disponível.');
      }
      itens.add(montador.montar(pedido, detalhes));
    }
    return LotePedidoVoz(
        texto: resposta['texto'] as String? ?? '',
        pedidos: pedidos,
        itens: itens);
  }

  Future<AberturaFalada> interpretarAbertura(
      String caminho, TipoAberturaVoz tipo) async {
    final resposta = await _requisicao(
        audio: FormData.fromMap({
      'audio': await MultipartFile.fromFile(caminho,
          filename: caminho.endsWith('.wav') ? 'abertura.wav' : 'abertura.m4a'),
      'finalidade': 'abertura',
      'tipo_atendimento': tipo.name,
    }));
    if (resposta['abertura'] is! Map) {
      throw const FalhaPedidoVoz('Nao foi possivel entender a abertura.');
    }
    return AberturaFalada.fromMap(resposta['abertura'] as Map, tipo);
  }

  Future<String> localizarClienteCadastrado(String nome) async {
    _validar();
    try {
      final resposta = await _voz.post('voz/clientes.php',
          data: {'nome': nome},
          options: Options(headers: {'X-Garcom-Voz': _token}),
          cancelToken: _cancelamento);
      _validar();
      final dados = resposta.data;
      if (dados is! Map ||
          dados['sucesso'] != true ||
          dados['id_cliente'] is! String ||
          !RegExp(r'^[1-9]\d*$').hasMatch(dados['id_cliente'] as String)) {
        throw const FalhaPedidoVoz(
            'Nao foi possivel selecionar o cliente cadastrado.');
      }
      return dados['id_cliente'] as String;
    } on DioException catch (erro) {
      final dados = erro.response?.data;
      if (dados is Map &&
          dados['mensagem'] is String &&
          (dados['mensagem'] as String).length < 600) {
        throw FalhaPedidoVoz(dados['mensagem'] as String);
      }
      throw const FalhaPedidoVoz(
          'Nao consegui consultar o cliente. Nenhuma abertura foi enviada.');
    }
  }

  Future<ResultadoPedidoVoz> interpretar(String caminho) async {
    final resposta = await _requisicao(
        audio: FormData.fromMap({
      'audio': await MultipartFile.fromFile(caminho,
          filename: caminho.endsWith('.wav') ? 'pedido.wav' : 'pedido.m4a'),
      'destino_voz': '1',
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
      destino: pedido.destino,
      item: montador.montar(pedido, detalhes)
    );
  }

  void dispose() {
    if (_cancelamento.isCancelled) return;
    _cancelamento.cancel();
    _clienteVoz?.close(force: true);
    _clienteCatalogo?.cliente.close(force: true);
  }
}
