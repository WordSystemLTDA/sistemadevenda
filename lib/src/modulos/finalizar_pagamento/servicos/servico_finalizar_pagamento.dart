import 'dart:convert';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/banco_pix_modelo.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/bancos_ativos_pdv_modelo.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/modelo_datas_vendas.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/parcelas_modelo_pdv.dart';
import 'package:dio/dio.dart';

class ServicoFinalizarPagamento {
  final DioCliente dio;
  UsuarioProvedor usuarioProvedor;

  ServicoFinalizarPagamento(this.dio, this.usuarioProvedor);

  Future<(bool, String, String)> pagarPedido(
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

    var response = await dio.cliente.post('${tipo.nomeSimplificado}/pagar_pedido.php', data: jsonEncode(campos));

    var jsonData = response.data;
    bool sucesso = jsonData['sucesso'];
    String mensagem = jsonData['mensagem'];
    String idVenda = jsonData['idVenda'] ?? '0';

    return (sucesso, mensagem, idVenda);
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
    final empresa = usuarioProvedor.usuario!.empresa;

    final url = '/tela_nfe_saida/listar_datas_vendas.php?empresa=$empresa';

    try {
      final response = await dio.cliente.get(url);

      var jsonData = response.data;

      return ModeloDatasVendas.fromMap(jsonData);
    } on DioException catch (_) {
      return null;
    }
  }

  Future<BancosAtivosPdvModelo> listarBancos() async {
    var idEmpresa = usuarioProvedor.usuario!.empresa;
    var idUsuario = usuarioProvedor.usuario!.id;
    var response = await dio.cliente.get('/tela_nfe_saida/listar_bancos.php?id_empresa=$idEmpresa&id_usuario=$idUsuario');

    var jsonData = response.data;

    var dados = BancosAtivosPdvModelo.fromMap(jsonData);

    return dados;
  }
}
