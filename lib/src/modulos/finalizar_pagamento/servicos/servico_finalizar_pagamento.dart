import 'dart:convert';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/notificador_atualizacao.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/banco_pix_modelo.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/bancos_ativos_pdv_modelo.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/modelo_datas_vendas.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/parcelas_modelo_pdv.dart';
import 'package:dio/dio.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/essencial/sincronizacao/atendimentos_locais.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';

class ServicoFinalizarPagamento {
  final DioCliente dio;
  UsuarioProvedor usuarioProvedor;

  ServicoFinalizarPagamento(this.dio, this.usuarioProvedor);

  Future<
      ({
        bool sucesso,
        String mensagem,
        bool finalizou,
        String idVenda,
        double totalPago,
      })> pagarContaAtendimento({
    required String id,
    required String idComanda,
    required String idMesa,
    required String cliente,
    required TipoCardapio tipo,
    required double valorLancamento,
    required double valorOriginal,
    required double valorAPagar,
    required double troco,
    required int pagamentoSelecionado,
    required int quantidadePessoas,
    required DateTime vencimento,
    required List<Modelowordprodutos> produtosParaFinalizar,
    required bool modoProdutoParcial,
    String valorTaxaServico = '0',
    String valorDesconto = '0',
    String valorAcrescimo = '0',
  }) async {
    if (tipo != TipoCardapio.comanda && tipo != TipoCardapio.mesa) {
      return (
        sucesso: false,
        mensagem: 'Este recebimento é exclusivo para Comanda ou Mesa.',
        finalizou: false,
        idVenda: '0',
        totalPago: 0.0,
      );
    }

    final idEmpresa = usuarioProvedor.usuario?.empresa ?? '';
    final idUsuario = usuarioProvedor.usuario?.id ?? '';
    if (idEmpresa.isEmpty || idUsuario.isEmpty) {
      return (
        sucesso: false,
        mensagem: 'Entre novamente para finalizar a conta.',
        finalizou: false,
        idVenda: '0',
        totalPago: 0.0,
      );
    }

    final produtosParciais = produtosParaFinalizar.map((produto) {
      final mapa = produto.toMap();
      mapa['iditensvenda'] = produto.iditensvenda;
      mapa['valorpago'] = produto.valorPago;
      mapa['quantidadePessoa'] = modoProdutoParcial ? 1 : 0;
      return mapa;
    }).toList();
    final dataVencimento = '${vencimento.year.toString().padLeft(4, '0')}-'
        '${vencimento.month.toString().padLeft(2, '0')}-'
        '${vencimento.day.toString().padLeft(2, '0')}';
    String moeda(double valor) => valor.toStringAsFixed(2);

    final campos = <String, dynamic>{
      'id_operacao': BancoLocal.novoId(),
      'id': id,
      'empresa': idEmpresa,
      'id_usuario': idUsuario,
      'cliente': cliente.isEmpty ? '0' : cliente,
      'valor_lancamento': moeda(valorLancamento),
      'valor_original': moeda(valorOriginal),
      'pagamentoSelecionado': pagamentoSelecionado,
      'quantidadePessoas': quantidadePessoas < 1 ? 1 : quantidadePessoas,
      'subTotal': moeda(valorAPagar),
      'dataLancamento': dataVencimento,
      'parcelas': '1',
      'parcelasLista': const <dynamic>[],
      'id_comanda': idComanda.isEmpty ? '0' : idComanda,
      'id_mesa': idMesa.isEmpty ? '0' : idMesa,
      'tipo': tipo.nome,
      'valortroco': moeda(troco),
      'valor_da_entrega': '0.00',
      'valordataxadeservico': valorTaxaServico,
      'valoresProduto': moeda(valorAPagar),
      'novo': false,
      'tipodeentrega': '0',
      'produtos': const <dynamic>[],
      'produtosParaFinalizar': produtosParciais,
      'valorAPagarOriginal': moeda(valorAPagar),
      'valorAPagar': moeda(valorAPagar),
      'editar_movimentacao': '0',
      'modoProdutoParcial': modoProdutoParcial,
      'obs': '',
      'valordesconto': valorDesconto,
      'valoracrescimo': valorAcrescimo,
    };

    ({
      bool sucesso,
      String mensagem,
      bool finalizou,
      String idVenda,
      double totalPago,
    }) interpretarResposta(Object? resposta) {
      if (resposta is! Map) {
        return (
          sucesso: false,
          mensagem: 'O servidor retornou uma resposta inválida.',
          finalizou: false,
          idVenda: '0',
          totalPago: 0.0,
        );
      }
      final jsonData = Map<String, dynamic>.from(resposta);
      final sucesso = jsonData['sucesso'] == true;
      final finalizou = jsonData['finalizouPedido']?.toString() == '1';
      if (sucesso) NotificadorAtualizacao.atendimento(tipo.nome);
      return (
        sucesso: sucesso,
        mensagem: jsonData['mensagem']?.toString() ??
            (sucesso ? 'Pagamento registrado.' : 'Pagamento não registrado.'),
        finalizou: finalizou,
        idVenda: jsonData['idVenda']?.toString() ?? '0',
        totalPago: double.tryParse(
                jsonData['somaValorHistorico']?.toString() ?? '0') ??
            0,
      );
    }

    Future<
        ({
          bool sucesso,
          String mensagem,
          bool finalizou,
          String idVenda,
          double totalPago,
        })> enviar() async {
      final response = await dio.cliente.post(
        '${tipo.nomeSimplificado}/pagar_pedido.php',
        data: jsonEncode(campos),
      );
      return interpretarResposta(response.data);
    }

    try {
      return await enviar();
    } on DioException catch (primeiroErro) {
      var erro = primeiroErro;
      if (primeiroErro.response == null) {
        // Repete exatamente a mesma operação. O recibo idempotente no servidor
        // devolve a resposta original caso o primeiro commit já tenha ocorrido.
        try {
          return await enviar();
        } on DioException catch (segundoErro) {
          erro = segundoErro;
        } catch (_) {
          return (
            sucesso: false,
            mensagem:
                'Não foi possível confirmar o pagamento. Atualize a conta antes de tentar novamente.',
            finalizou: false,
            idVenda: '0',
            totalPago: 0.0,
          );
        }
      }
      final dados = erro.response?.data;
      final mensagem = dados is Map ? dados['mensagem']?.toString() : null;
      return (
        sucesso: false,
        mensagem: mensagem?.isNotEmpty == true
            ? mensagem!
            : 'Não foi possível confirmar o pagamento. Verifique a conexão e atualize a conta antes de tentar novamente.',
        finalizou: false,
        idVenda: '0',
        totalPago: 0.0,
      );
    } catch (_) {
      return (
        sucesso: false,
        mensagem: 'Não foi possível confirmar o pagamento.',
        finalizou: false,
        idVenda: '0',
        totalPago: 0.0,
      );
    }
  }

  Future<
      ({
        bool sucesso,
        String mensagem,
        String idVenda,
        String numeroPedido,
      })> pagarPedido(
    String id,
    String idComanda,
    String idMesa,
    String cliente,
    String valorLancamento,
    String valorOriginal,
    int pagamentoSelecionado,
    int quantidadePessoas,
    String subTotal,
    String dataLancamento,
    String parcelas,
    List<ParcelasModelo> parcelasLista,
    TipoCardapio tipo,
    String valortroco,
    String valordaentrega,
    String valoresProduto,
    bool novo,
    String tipodeentrega,
    List<Modelowordprodutos> produtos,
    String valorAPagarOriginal,
    String obs,
  ) async {
    var idEmpresa = usuarioProvedor.usuario!.empresa;
    var idUsuario = usuarioProvedor.usuario!.id;

    for (var element in parcelasLista) {
      element.vencimentoController = null;
      element.valorController = null;
    }

    var campos = {
      'id': id,
      'empresa': idEmpresa,
      'id_usuario': idUsuario,
      'cliente': cliente,
      'valor_lancamento': valorLancamento,
      'valor_original': valorOriginal,
      'pagamentoSelecionado': pagamentoSelecionado,
      'quantidadePessoas': quantidadePessoas,
      'subTotal': subTotal,
      'dataLancamento': dataLancamento,
      'parcelas': parcelas,
      'parcelasLista': parcelasLista,
      'id_comanda': idComanda,
      'id_mesa': idMesa,
      'tipo': tipo.nome,
      'valortroco': valortroco,
      'valor_da_entrega': valordaentrega,
      'valoresProduto': valoresProduto,
      'novo': novo,
      'tipodeentrega': tipodeentrega,
      'id_endereco': '',
      'obs': obs,
      'produtos': produtos.toList(),
      'valorAPagarOriginal': valorAPagarOriginal,
    };

    try {
      final sync = Sincronizador.instancia;
      if (sync != null &&
          tipo == TipoCardapio.balcao &&
          (id.startsWith('venda-local:') ||
              ((id.isEmpty || id == '0') &&
                  await sync.prepararAberturasOffline()))) {
        final dados = jsonDecode(jsonEncode(campos)) as Map<String, dynamic>;
        dados['produtos'] = produtos.map((p) => p.toMap()).toList();
        if (id.startsWith('venda-local:')) {
          await sync.guardarPagamentoVenda(id, dados);
          return (
            sucesso: true,
            mensagem: 'Pagamento salvo no aparelho.',
            idVenda: id,
            numeroPedido: '',
          );
        }
        await sync.configurar();
        final nomeCliente = await AtendimentosLocais(sync.banco, sync.escopo)
            .nomeCliente(cliente);
        final mensagens = Impressao.prepararComprovanteDePedido(
            produtos: produtos,
            tipoTela: tipo,
            tipodeentrega: tipodeentrega,
            nomeCliente: nomeCliente.isEmpty ? obs : nomeCliente,
            nomeEmpresa: usuarioProvedor.usuario?.nomeEmpresa ?? '',
            comanda: 'Balcão',
            numeroPedido: '');
        final idLocal = await sync.guardarVenda(
            contexto: ContextoCarrinho(
                empresa: idEmpresa!, tipo: 'balcao', idAtendimento: id),
            itens: produtos,
            dados: dados,
            impressoes: mensagens);
        return (
          sucesso: true,
          mensagem: 'Venda salva no aparelho.',
          idVenda: idLocal,
          numeroPedido: '',
        );
      }

      var response = await dio.cliente.post(
          '${tipo.nomeSimplificado}/pagar_pedido.php',
          data: jsonEncode(campos));

      var jsonData = response.data;
      bool sucesso = jsonData['sucesso'];
      String mensagem = jsonData['mensagem'];
      String idVenda = jsonData['idVenda'] ?? '0';
      String numeroPedido = jsonData['numeroPedido']?.toString().trim() ?? '';
      if (sucesso && tipo == TipoCardapio.balcao) {
        NotificadorAtualizacao.atendimento('Balcão');
      }

      return (
        sucesso: sucesso,
        mensagem: mensagem,
        idVenda: idVenda,
        numeroPedido: numeroPedido,
      );
    } catch (erro) {
      return (
        sucesso: false,
        mensagem: erro is StateError
            ? erro.message.toString()
            : 'Nao foi possivel confirmar o pagamento. Confira o servidor antes de tentar novamente.',
        idVenda: id,
        numeroPedido: '',
      );
    }
  }

  Future<List<BancoPixModelo>> listarBancoPix() async {
    final empresa = usuarioProvedor.usuario!.empresa;

    final url = '/tela_nfe_saida/listar_banco_pix.php?empresa=$empresa';

    try {
      final response = await dio.cliente.get(url);
      var jsonData = response.data;

      return List<BancoPixModelo>.from(jsonData.map((elemento) {
        return BancoPixModelo.fromMap(elemento);
      }));
    } on DioException catch (_) {
      return [];
    }
  }

  Future<ModeloDatasVendas?> listarDatasVendas() async {
    final empresa = usuarioProvedor.usuario?.empresa?.trim() ?? '';
    if (empresa.isEmpty) return ModeloDatasVendas.padrao();

    const url = '/tela_nfe_saida/listar_datas_vendas.php';

    try {
      final response = await dio.cliente.get(
        url,
        queryParameters: {'empresa': empresa},
        options: Options(extra: const {'semCache': true}),
      );
      return _datasVendasDaResposta(response.data);
    } on DioException {
      // Sem rede, a segunda chamada permite que o cache offline responda.
      try {
        final response = await dio.cliente.get(
          url,
          queryParameters: {'empresa': empresa},
        );
        return _datasVendasDaResposta(response.data);
      } catch (_) {
        return ModeloDatasVendas.padrao();
      }
    } catch (_) {
      return ModeloDatasVendas.padrao();
    }
  }

  ModeloDatasVendas _datasVendasDaResposta(Object? dados) {
    if (dados is Map) {
      return ModeloDatasVendas.fromMap(Map<String, dynamic>.from(dados));
    }
    return ModeloDatasVendas.padrao();
  }

  Future<BancosAtivosPdvModelo> listarBancos() async {
    var idEmpresa = usuarioProvedor.usuario!.empresa;
    var idUsuario = usuarioProvedor.usuario!.id;
    var response = await dio.cliente.get(
        '/tela_nfe_saida/listar_bancos.php?id_empresa=$idEmpresa&id_usuario=$idUsuario');

    var jsonData = response.data;

    var dados = BancosAtivosPdvModelo.fromMap(jsonData);

    return dados;
  }
}
