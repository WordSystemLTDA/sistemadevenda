import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/produto/modelos/acompanhamentos_modelo.dart';
import 'package:app/src/modulos/produto/modelos/adicionais_modelo.dart';
import 'package:app/src/modulos/produto/modelos/tamanhos_modelo.dart';
import 'package:dio/dio.dart';

class ServicoProduto {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;
  ServicoProduto(this.dio, this.usuarioProvedor);
  // final sharedPrefs = SharedPrefsConfig();

  // var usuarioProvider = usuarioProvider.getUsuario();
  // late final empresa = usuarioProvider['empresa'];
  // late final idUsuario = usuarioProvider['id'];

  Future<List<Modelowordprodutos>> listarPorCategoria(
      String categoria, int pagina) async {
    var empresa = usuarioProvedor.usuario!.empresa;
    var idusuario = usuarioProvedor.usuario!.id;

    final response = await dio.cliente.get(
        'produtos/listar_por_categoria.php?categoria=$categoria&empresa=$empresa&id_usuario=$idusuario&pagina=$pagina');
    // print(response.realUri);

    if (response.statusCode == 200) {
      if (response.data.isNotEmpty) {
        return List<Modelowordprodutos>.from(response.data.map((elemento) {
          return Modelowordprodutos.fromMap(elemento);
        }));
      } else {
        return [];
      }
    } else {
      return [];
    }
  }

  Future<List<Modelowordprodutos>> listarPorNome(
      String pesquisa, String categoria, String idcliente,
      {bool codigoExato = false}) async {
    var empresa = usuarioProvedor.usuario!.empresa;
    var idusuario = usuarioProvedor.usuario!.id;
    final response =
        await dio.cliente.get('produtos/listar.php', queryParameters: {
      'pesquisa': pesquisa,
      'empresa': empresa,
      'categoria': categoria,
      'id_usuario': idusuario,
      'id_cliente': idcliente,
      'codigo_exato': codigoExato ? 'Sim' : 'Não',
    });

    if (response.statusCode == 200) {
      if (response.data.isNotEmpty) {
        return List<Modelowordprodutos>.from(response.data.map((elemento) {
          return Modelowordprodutos.fromMap(elemento);
        }));
      } else {
        return [];
      }
    } else {
      return [];
    }
  }

  Future<Modelowordprodutos?> listarPorId(
      String id, String idtamanhospizza) async {
    final empresa = usuarioProvedor.usuario!.empresa ?? '';
    final idUsuario = usuarioProvedor.usuario!.id ?? '';
    final response = await dio.cliente.get(
        '/produtos/listar_por_id.php?id=$id&empresa=$empresa&id_usuario=$idUsuario&id_tamanhos_pizza=$idtamanhospizza',
        options: Options(extra: {'atualizarMontagemCardapio': true}));

    if (response.data == null) return null;

    final produto = Modelowordprodutos.fromMap(response.data);
    return _completarMontagemCardapioSeNecessario(
      produto,
      empresa: empresa,
      idUsuario: idUsuario,
      baseGarcom: response.requestOptions.baseUrl,
    );
  }

  bool _idCardapioValido(String? id) =>
      (int.tryParse((id ?? '').trim()) ?? 0) > 0;

  bool _grupoMontagemCardapio(Modelowordprodutos produto) {
    return (produto.opcoesPacotes ?? []).any((grupo) =>
        grupo.tipo == 8 ||
        grupo.id == 12 ||
        (grupo.dados ?? [])
            .any((dado) => _idCardapioValido(dado.idCategoriaCardapio)));
  }

  Future<Modelowordprodutos> _completarMontagemCardapioSeNecessario(
    Modelowordprodutos produto, {
    required String empresa,
    required String idUsuario,
    required String baseGarcom,
  }) async {
    if (_grupoMontagemCardapio(produto) || produto.categoria.trim().isEmpty) {
      return produto;
    }

    final baseDesktop = _baseDesktop(baseGarcom);
    if (baseDesktop == null) return produto;

    final produtoDesktop = await _buscarProdutoDesktop(
      produto,
      empresa: empresa,
      idUsuario: idUsuario,
      baseDesktop: baseDesktop,
    );
    if (produtoDesktop == null || !_grupoMontagemCardapio(produtoDesktop)) {
      return produto;
    }

    if (!_idCardapioValido(produto.idCategoriaCardapio)) {
      produto.idCategoriaCardapio = produtoDesktop.idCategoriaCardapio;
    }
    produto.habilTipo = 'Pacote';
    final montagemDesktop = (produtoDesktop.opcoesPacotes ?? [])
        .where(_grupoEhMontagemCardapio)
        .map((grupo) => ModeloOpcoesPacotes.fromMap(grupo.toMap()))
        .toList();
    final atuais = (produto.opcoesPacotes ?? [])
        .where((grupo) => !_grupoEhMontagemCardapio(grupo))
        .map((grupo) => ModeloOpcoesPacotes.fromMap(grupo.toMap()))
        .toList();
    final extrasDesktop = (produtoDesktop.opcoesPacotes ?? [])
        .where((grupo) => !_grupoEhMontagemCardapio(grupo))
        .where((grupo) => !atuais.any((atual) => atual.id == grupo.id))
        .map((grupo) => ModeloOpcoesPacotes.fromMap(grupo.toMap()))
        .toList();

    produto.opcoesPacotes = [
      ...montagemDesktop,
      ...atuais,
      ...extrasDesktop,
    ];
    return produto;
  }

  bool _grupoEhMontagemCardapio(ModeloOpcoesPacotes grupo) =>
      grupo.tipo == 8 ||
      grupo.id == 12 ||
      (grupo.dados ?? [])
          .any((dado) => _idCardapioValido(dado.idCategoriaCardapio));

  String? _baseDesktop(String baseGarcom) {
    if (baseGarcom.isEmpty) return null;
    final normalizada = baseGarcom.endsWith('/') ? baseGarcom : '$baseGarcom/';
    final local = normalizada.replaceFirst(
      '/api_restaurantes_venda/api1/',
      '/api_desktop/1.0.01/',
    );
    if (local != normalizada) return local;

    final online = normalizada.replaceFirst(
      '/api_restaurantes_venda/api6/',
      '/api_desktop/1.0.01/',
    );
    return online == normalizada ? null : online;
  }

  Future<Modelowordprodutos?> _buscarProdutoDesktop(
    Modelowordprodutos produto, {
    required String empresa,
    required String idUsuario,
    required String baseDesktop,
  }) async {
    for (var pagina = 1; pagina <= 10; pagina++) {
      try {
        final response = await dio.cliente.get(
          'produtos/listar_por_categoria.php',
          queryParameters: {
            'categoria': produto.categoria,
            'empresa': empresa,
            'id_usuario': idUsuario,
            'pagina': pagina,
          },
          options: Options(extra: {
            'semCache': true,
            'servidorFixo': baseDesktop,
          }),
        );
        final lista = _listaMapas(response.data);
        final encontrado = lista.where((item) =>
            item['id']?.toString() == produto.id ||
            (produto.codigo.trim().isNotEmpty &&
                item['codigo']?.toString() == produto.codigo));
        if (encontrado.isNotEmpty) {
          return Modelowordprodutos.fromMap(encontrado.first);
        }
        if (lista.isEmpty) return null;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _listaMapas(Object? dados) {
    final lista = dados is List
        ? dados
        : dados is Map
            ? (dados['dados'] ?? dados['produtos'] ?? dados['data'])
            : null;
    if (lista is! List) return const [];
    return [
      for (final item in lista)
        if (item is Map) Map<String, dynamic>.from(item)
    ];
  }

  Future<List<AdicionaisModelo>> listarAdicionais(String id) async {
    final url = '/produtos/listar_adicionais.php?produto=$id';

    final response = await dio.cliente.get(url);

    if (response.data.isNotEmpty) {
      return List<AdicionaisModelo>.from(response.data.map((e) {
        return AdicionaisModelo.fromMap(e);
      }));
    }

    return [];
  }

  Future<List<AcompanhamentosModelo>> listarAcompanhamentos(String id) async {
    final url = '/produtos/listar_acompanhamentos.php?produto=$id';

    final response = await dio.cliente.get(url);

    if (response.data.isNotEmpty) {
      return List<AcompanhamentosModelo>.from(response.data.map((e) {
        return AcompanhamentosModelo.fromMap(e);
      }));
    }

    return [];
  }

  Future<List<TamanhosModelo>> listarTamanhos(String id) async {
    final url = '/produtos/listar_tamanhos.php?produto=$id';

    final response = await dio.cliente.get(url);

    if (response.data.isNotEmpty) {
      return List<TamanhosModelo>.from(response.data.map((e) {
        return TamanhosModelo.fromMap(e);
      }));
    }

    return [];
  }

  Future<bool> inserir(dynamic idComanda, dynamic valor, dynamic observacaoMesa,
      dynamic idProduto, dynamic quantidade, dynamic observacao) async {
    // const url = '${Apis.baseUrl}pedidos/inserir.php';

    // final response = await dio.post(
    //   url,
    //   data: jsonEncode({
    //     'idComanda': idComanda,
    //     'valor': valor,
    //     'observacaoMesa': observacaoMesa,
    //     'idProduto': idProduto,
    //     'quantidade': quantidade,
    //     'observacao': observacao,
    //   }),
    //   options: Options(headers: {
    //     HttpHeaders.contentTypeHeader: 'application/json',
    //   }),
    // );

    // final Map<dynamic, dynamic> result = response.data;
    // final bool sucesso = result['sucesso'];

    // if (response.statusCode == 200 && sucesso == true) {
    //   return sucesso;
    // }

    return false;
  }
}
