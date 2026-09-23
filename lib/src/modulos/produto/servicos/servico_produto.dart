import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/produto/modelos/acompanhamentos_modelo.dart';
import 'package:app/src/modulos/produto/modelos/adicionais_modelo.dart';
import 'package:app/src/modulos/produto/modelos/tamanhos_modelo.dart';
import 'package:dio/dio.dart';

class _DetalheAntecipado {
  final DateTime criadoEm;
  final String assinatura;
  final Future<Modelowordprodutos?> consulta;

  const _DetalheAntecipado({
    required this.criadoEm,
    required this.assinatura,
    required this.consulta,
  });
}

class ServicoProduto {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;
  ServicoProduto(this.dio, this.usuarioProvedor);
  static final Map<String, Future<List<Map<String, dynamic>>>>
      _catalogosDesktop = {};
  final Map<String, _DetalheAntecipado> _detalhesAntecipados = {};
  static const _validadeDetalheAntecipado = Duration(seconds: 20);
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
        final produtos =
            List<Modelowordprodutos>.from(response.data.map((elemento) {
          return Modelowordprodutos.fromMap(elemento);
        }));
        _anteciparMontagensDoCatalogo(produtos);
        return produtos;
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
        final produtos =
            List<Modelowordprodutos>.from(response.data.map((elemento) {
          return Modelowordprodutos.fromMap(elemento);
        }));
        _anteciparMontagensDoCatalogo(produtos);
        return produtos;
      } else {
        return [];
      }
    } else {
      return [];
    }
  }

  Future<Modelowordprodutos?> listarPorId(
    String id,
    String idtamanhospizza, {
    bool modeloRecorrente = false,
  }) async {
    final chave = _chaveDetalhe(id, idtamanhospizza, modeloRecorrente);
    final antecipado = _detalhesAntecipados[chave];
    if (antecipado != null &&
        DateTime.now().difference(antecipado.criadoEm) <=
            _validadeDetalheAntecipado) {
      final produto = await antecipado.consulta;
      if (produto != null) {
        return Modelowordprodutos.fromMap(produto.toMap());
      }
    } else if (antecipado != null) {
      _detalhesAntecipados.remove(chave);
    }

    return _consultarPorId(
      id,
      idtamanhospizza,
      modeloRecorrente: modeloRecorrente,
    );
  }

  /// Inicia a mesma consulta usada pela tela do produto sem bloquear o toque.
  ///
  /// O resultado fica somente na memoria por poucos segundos e e consumido
  /// por [listarPorId]. Isso permite preparar bordas e adicionais enquanto o
  /// usuario ainda escolhe os sabores, sem persistir precos ou configuracoes
  /// que podem mudar no servidor.
  void anteciparDetalhesPorId(
    String id,
    String idtamanhospizza, {
    bool modeloRecorrente = false,
  }) {
    final chave = _chaveDetalhe(id, idtamanhospizza, modeloRecorrente);
    final agora = DateTime.now();
    final existente = _detalhesAntecipados[chave];
    if (existente != null &&
        agora.difference(existente.criadoEm) <= _validadeDetalheAntecipado) {
      return;
    }

    late final Future<Modelowordprodutos?> consulta;
    consulta = _consultarPorId(
      id,
      idtamanhospizza,
      modeloRecorrente: modeloRecorrente,
    ).then<Modelowordprodutos?>((produto) => produto,
        onError: (Object _, StackTrace __) {
      final atual = _detalhesAntecipados[chave];
      if (atual != null && identical(atual.consulta, consulta)) {
        _detalhesAntecipados.remove(chave);
      }
      return null;
    });

    _detalhesAntecipados[chave] = _DetalheAntecipado(
      criadoEm: agora,
      assinatura: 'produto:$id:$idtamanhospizza:$modeloRecorrente',
      consulta: consulta,
    );
    unawaited(consulta);

    Timer(_validadeDetalheAntecipado, () {
      final atual = _detalhesAntecipados[chave];
      if (atual != null && identical(atual.consulta, consulta)) {
        _detalhesAntecipados.remove(chave);
      }
    });
  }

  Future<Modelowordprodutos?> _consultarPorId(
    String id,
    String idtamanhospizza, {
    required bool modeloRecorrente,
  }) async {
    final empresa = usuarioProvedor.usuario!.empresa ?? '';
    final idUsuario = usuarioProvedor.usuario!.id ?? '';
    final response = await dio.cliente.get(
      '/produtos/listar_por_id.php',
      queryParameters: {
        'id': id,
        'empresa': empresa,
        'id_usuario': idUsuario,
        'id_tamanhos_pizza': idtamanhospizza,
        if (modeloRecorrente) 'modelo_recorrente': 'Sim',
      },
      options: Options(extra: {'atualizarMontagemCardapio': true}),
    );

    if (response.data == null) return null;

    final produto = Modelowordprodutos.fromMap(response.data);
    final produtoCompleto = await _completarMontagemCardapioSeNecessario(
      produto,
      empresa: empresa,
      idUsuario: idUsuario,
      baseGarcom: response.requestOptions.baseUrl,
      modeloRecorrente: modeloRecorrente,
    );
    return _completarPermissoesMontagemCardapio(
      produtoCompleto,
      empresa: empresa,
      idUsuario: idUsuario,
      baseGarcom: response.requestOptions.baseUrl,
    );
  }

  void _anteciparMontagensDoCatalogo(List<Modelowordprodutos> produtos) {
    final porCategoria = <String, List<Modelowordprodutos>>{};
    for (final produto in produtos) {
      final categoria = produto.idCategoriaCardapio?.trim() ?? '';
      if (!_idCardapioValido(categoria) || _grupoMontagemCardapio(produto)) {
        continue;
      }
      porCategoria.putIfAbsent(categoria, () => []).add(produto);
    }

    // Uma montagem e compartilhada pelos produtos vinculados a mesma
    // Categoria Cardapio. Antecipar somente o primeiro de cada categoria
    // evita uma requisicao por card e deixa o toque pronto na maioria dos
    // casos. O limite cobre os cards visiveis sem sobrecarregar a API.
    for (final produtosCategoria in porCategoria.values.take(4)) {
      final produto = produtosCategoria.first;
      final chave = _chaveDetalhe(produto.id, '0', false);
      final assinatura = jsonEncode({
        'categoria': produto.idCategoriaCardapio,
        'valor': produto.valorVenda,
        'opcoes': produto.opcoesPacotes?.map((e) => e.toMap()).toList(),
      });
      final existente = _detalhesAntecipados[chave];
      if (existente != null &&
          existente.assinatura == assinatura &&
          DateTime.now().difference(existente.criadoEm) <
              const Duration(seconds: 5)) {
        continue;
      }

      late final Future<Modelowordprodutos?> consulta;
      consulta = _consultarPorId(
        produto.id,
        '0',
        modeloRecorrente: false,
      ).then<Modelowordprodutos?>((detalhe) {
        if (detalhe != null) {
          _aplicarMontagemAntecipada(produtosCategoria, detalhe);
        }
        return detalhe;
      }, onError: (Object _, StackTrace __) {
        final atual = _detalhesAntecipados[chave];
        if (atual != null && identical(atual.consulta, consulta)) {
          _detalhesAntecipados.remove(chave);
        }
        return null;
      });
      _detalhesAntecipados[chave] = _DetalheAntecipado(
        criadoEm: DateTime.now(),
        assinatura: assinatura,
        consulta: consulta,
      );
      unawaited(consulta);

      Timer(_validadeDetalheAntecipado, () {
        final atual = _detalhesAntecipados[chave];
        if (atual != null && identical(atual.consulta, consulta)) {
          _detalhesAntecipados.remove(chave);
        }
      });
    }
  }

  void _aplicarMontagemAntecipada(
    List<Modelowordprodutos> produtos,
    Modelowordprodutos detalhe,
  ) {
    final montagem = (detalhe.opcoesPacotes ?? [])
        .where(_grupoEhMontagemCardapio)
        .firstOrNull;
    if (montagem == null || (montagem.dados?.isEmpty ?? true)) return;

    for (final produto in produtos) {
      final atuais = (produto.opcoesPacotes ?? [])
          .where((grupo) => !_grupoEhMontagemCardapio(grupo))
          .map((grupo) => ModeloOpcoesPacotes.fromMap(grupo.toMap()))
          .toList();
      produto
        ..habilTipo = 'Pacote'
        ..opcoesPacotes = [
          ModeloOpcoesPacotes.fromMap(montagem.toMap()),
          ...atuais,
        ];
    }
  }

  String _chaveDetalhe(
    String id,
    String tamanho,
    bool modeloRecorrente,
  ) {
    final empresa = usuarioProvedor.usuario?.empresa ?? '';
    final usuario = usuarioProvedor.usuario?.id ?? '';
    return '$empresa|$usuario|$id|$tamanho|$modeloRecorrente';
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
    required bool modeloRecorrente,
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
      modeloRecorrente: modeloRecorrente,
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

  Future<Modelowordprodutos> _completarPermissoesMontagemCardapio(
    Modelowordprodutos produto, {
    required String empresa,
    required String idUsuario,
    required String baseGarcom,
  }) async {
    final grupos =
        (produto.opcoesPacotes ?? []).where(_grupoEhMontagemCardapio).toList();
    final ingredientes = grupos
        .expand((grupo) => grupo.dados ?? const <ModeloDadosOpcoesPacotes>[])
        .toList();
    if (ingredientes.isEmpty ||
        ingredientes
            .every((item) => item.permissoesMontagemCardapio.isNotEmpty)) {
      return produto;
    }

    final categoria = ingredientes
        .map((item) => item.idCategoriaCardapio)
        .whereType<String>()
        .where(_idCardapioValido)
        .firstOrNull;
    final diaSemana = ingredientes
        .map((item) => item.diaSemana)
        .whereType<String>()
        .where((dia) => dia.trim().isNotEmpty)
        .firstOrNull;
    final baseDesktop = _baseDesktop(baseGarcom);
    if (categoria == null || diaSemana == null || baseDesktop == null) {
      return produto;
    }

    try {
      final response = await dio.cliente.get(
        'cardapio/vincular_cardapio/listar_ingredientes_dia.php',
        queryParameters: {
          'empresa': empresa,
          'id_usuario': idUsuario,
          'id_categoria_cardapio': categoria,
          'dia_semana': diaSemana,
        },
        options: Options(extra: {
          'semCache': true,
          'servidorFixo': baseDesktop,
        }),
      );
      final resposta = response.data;
      final lista = resposta is Map ? resposta['ingredientes'] : null;
      if (lista is! List) return produto;

      final permissoesPorIngrediente = <String, Map<String, bool>>{};
      for (final bruto in lista) {
        if (bruto is! Map) continue;
        final mapa = Map<String, dynamic>.from(bruto);
        final id = (mapa['idIngredienteCardapio'] ??
                mapa['id_ingrediente_cardapio'] ??
                mapa['id'])
            ?.toString();
        if (id == null || id.isEmpty) continue;
        permissoesPorIngrediente[id] = {
          'sem': _permissaoAtiva(mapa['permitirSem'] ?? mapa['permitir_sem']),
          'pouco':
              _permissaoAtiva(mapa['permitirPouco'] ?? mapa['permitir_pouco']),
          'normal': _permissaoAtiva(
              mapa['permitirNormal'] ?? mapa['permitir_normal']),
          'mais':
              _permissaoAtiva(mapa['permitirMais'] ?? mapa['permitir_mais']),
          'trocar': _permissaoAtiva(
              mapa['permitirTrocar'] ?? mapa['permitir_trocar']),
        };
      }

      for (final grupo in grupos) {
        final dados = grupo.dados;
        if (dados == null) continue;
        for (var i = 0; i < dados.length; i++) {
          if (dados[i].permissoesMontagemCardapio.isNotEmpty) continue;
          final permissoes = permissoesPorIngrediente[dados[i].id];
          if (permissoes == null) continue;
          dados[i] = ModeloDadosOpcoesPacotes.fromMap({
            ...dados[i].toMap(),
            'permissoesMontagemCardapio': permissoes,
          });
        }
      }
    } catch (_) {
      return produto;
    }
    return produto;
  }

  bool _permissaoAtiva(Object? valor) {
    if (valor == null) return true;
    if (valor is bool) return valor;
    final texto = valor.toString().trim().toLowerCase();
    return texto == 'sim' || texto == '1' || texto == 'true';
  }

  bool _grupoEhMontagemCardapio(ModeloOpcoesPacotes grupo) =>
      grupo.tipo == 8 ||
      grupo.id == 12 ||
      (grupo.dados ?? [])
          .any((dado) => _idCardapioValido(dado.idCategoriaCardapio));

  String? _baseDesktop(String baseGarcom) {
    if (baseGarcom.isEmpty) return null;
    final normalizada = baseGarcom.endsWith('/') ? baseGarcom : '$baseGarcom/';
    final desktop = normalizada.replaceFirst(
      RegExp(r'/api_restaurantes_venda/api(?:1|6|37)/'),
      '/api_desktop/1.0.01/',
    );
    return desktop == normalizada ? null : desktop;
  }

  Future<Modelowordprodutos?> _buscarProdutoDesktop(
    Modelowordprodutos produto, {
    required String empresa,
    required String idUsuario,
    required String baseDesktop,
    required bool modeloRecorrente,
  }) async {
    for (var pagina = 1; pagina <= 10; pagina++) {
      try {
        final lista = await _listarCategoriaDesktop(
          categoria: produto.categoria,
          empresa: empresa,
          idUsuario: idUsuario,
          pagina: pagina,
          baseDesktop: baseDesktop,
          modeloRecorrente: modeloRecorrente,
        );
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

  Future<List<Map<String, dynamic>>> _listarCategoriaDesktop({
    required String categoria,
    required String empresa,
    required String idUsuario,
    required int pagina,
    required String baseDesktop,
    bool modeloRecorrente = false,
  }) {
    final chave =
        '$baseDesktop|$empresa|$idUsuario|$categoria|$pagina|$modeloRecorrente';
    return _catalogosDesktop.putIfAbsent(chave, () async {
      try {
        final response = await dio.cliente.get(
          'produtos/listar_por_categoria.php',
          queryParameters: {
            'categoria': categoria,
            'empresa': empresa,
            'id_usuario': idUsuario,
            'pagina': pagina,
            if (modeloRecorrente) 'modelo_recorrente': 'Sim',
          },
          options: Options(extra: {
            'semCache': true,
            'servidorFixo': baseDesktop,
          }),
        );
        return _listaMapas(response.data);
      } catch (_) {
        return const <Map<String, dynamic>>[];
      } finally {
        // Compartilha somente a consulta em andamento. Reter o Future pronto
        // aqui mantinha ingredientes/precos do desktop por toda a sessao.
        _catalogosDesktop.remove(chave);
      }
    });
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
