import 'dart:convert';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_destino_impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_nome_lancamento.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:flutter_modular/flutter_modular.dart';

class Impressao {
  static Future<void> comprovanteDePedido({
    List<Modelowordprodutos> produtos = const [],
    String comanda = 'Sem Comanda',
    String numeroPedido = '0',
    String nomeCliente = '',
    String nomeEmpresa = '',
    String tipodeentrega = '',
    String local = '',
    TipoCardapio tipoTela = TipoCardapio.balcao,
    bool imprimirSomenteLocal = false,
    bool enviarDeVolta = true,
  }) async {
    var server = Modular.get<Server>();
    // var client = Modular.get<Client>();
    var usuario = Modular.get<UsuarioProvedor>();

    for (var element in produtos) {
      element.quantidadeController = null;
    }

    // var nomedopcLocal = '';

    // nomedopcLocal = server.nomedopc;

    // var produtosOutroPC = produtos.where((element) => element.destinoDeImpressao?.nomedopc != nomedopcLocal);
    // var produtosNessePC = produtos.where((element) => element.destinoDeImpressao?.nomedopc == nomedopcLocal);

    // if (client.connected && enviarDeVolta == true) {
    //   if (produtosOutroPC.isNotEmpty) {
    //     client.write(jsonEncode({
    //       'tipo': tipoTela.nome,
    //       'tipoImpressao': '1',
    //       'nomeConexao': usuario.usuario?.nome ?? 'Sem Nome',
    //       'produtos': produtosOutroPC.map((e) => e.toMap()).toList(),
    //       'comanda': comanda,
    //       'numeroPedido': numeroPedido,
    //       'nomeCliente': nomeCliente,
    //       'nomeEmpresa': nomeEmpresa,
    //       'tipodeentrega': tipodeentrega,
    //       'local': local,
    //       'nomeUsuario': usuario.usuario?.nome ?? '',
    //       'idEmpresa': usuario.usuario?.empresa ?? '0',
    //       'idUsuario': usuario.usuario?.id ?? '1',
    //       'enviarDeVolta': enviarDeVolta,
    //     }));
    //   }
    // } else if (client.connected && enviarDeVolta == false) {
    //   if (produtosNessePC.isNotEmpty) {
    //     server.write(jsonEncode({
    //       'tipo': tipoTela.nome,
    //       'tipoImpressao': '1',
    //       'nomeConexao': usuario.usuario?.nome ?? 'Sem Nome',
    //       'produtos': produtosNessePC.map((e) => e.toMap()).toList(),
    //       'comanda': comanda,
    //       'numeroPedido': numeroPedido,
    //       'nomeCliente': nomeCliente,
    //       'nomeEmpresa': nomeEmpresa,
    //       'tipodeentrega': tipodeentrega,
    //       'local': local,
    //       'nomeUsuario': usuario.usuario?.nome ?? '',
    //       'idEmpresa': usuario.usuario?.empresa ?? '0',
    //       'idUsuario': usuario.usuario?.id ?? '1',
    //       'enviarDeVolta': enviarDeVolta,
    //     }));
    //   }
    // }

    if (server.connected && enviarDeVolta == true) {
      // Caso for servidor e a rede não estiver conectada
      // if (server.connected && client.connected == false) {

      if (produtos.isNotEmpty) {
        server.write(jsonEncode({
          'tipo': tipoTela.nome,
          'tipoImpressao': '1',
          'nomeConexao': usuario.usuario?.nome ?? 'Sem Nome',
          'produtos': produtos.map((e) => e.toMap()).toList(),
          'comanda': comanda,
          'numeroPedido': numeroPedido,
          'nomeCliente': nomeCliente,
          'nomeEmpresa': nomeEmpresa,
          'tipodeentrega': tipodeentrega,
          'local': local,
          'nomeUsuario': usuario.usuario?.nome ?? '',
          'idEmpresa': usuario.usuario?.empresa ?? '0',
          'idUsuario': usuario.usuario?.id ?? '1',
          'enviarDeVolta': enviarDeVolta,
        }));
      }
      // else if (produtosNessePC.isNotEmpty) {
      //   server.write(jsonEncode({
      //     'tipo': tipoTela.nome,
      //     'tipoImpressao': '1',
      //     'nomeConexao': usuario.usuario?.nome ?? 'Sem Nome',
      //     'produtos': produtosNessePC.map((e) => e.toMap()).toList(),
      //     'comanda': comanda,
      //     'numeroPedido': numeroPedido,
      //     'nomeCliente': nomeCliente,
      //     'nomeEmpresa': nomeEmpresa,
      //     'tipodeentrega': tipodeentrega,
      //     'local': local,
      //     'nomeUsuario': usuario.usuario?.nome ?? '',
      //     'idEmpresa': usuario.usuario?.empresa ?? '0',
      //     'idUsuario': usuario.usuario?.id ?? '1',
      //     'enviarDeVolta': enviarDeVolta,
      //   }));
      // }
    }
  }

  static Future<void> comprovanteDeCupomNaoFiscal({
    ModeloDestinoImpressao? destinoDeImpressao,
    String idVenda = '0',
    String tipo = '',
  }) async {
    var server = Modular.get<Server>();
    var usuario = Modular.get<UsuarioProvedor>();

    if (server.connected) {
      server.write(jsonEncode({
        'tipoImpressao': '4',
        'nomeConexao': usuario.usuario?.nome ?? 'Sem Nome',
        'destinoDeImpressao': destinoDeImpressao,
        'idVenda': idVenda,
        'tipo': tipo,
        'nomeUsuario': usuario.usuario?.nome ?? '',
        'idEmpresa': usuario.usuario?.empresa ?? '0',
        'idUsuario': usuario.usuario?.id ?? '1',
      }));
    }
  }

  static Future<void> comprovanteDeCupomFiscal({
    ModeloDestinoImpressao? destinoDeImpressao,
    String idVenda = '0',
    String tipo = '',
  }) async {
    // ComprovanteDeCupomFiscal(
    //   idVenda,
    //   destinoDeImpressao!,
    // ).call(tipo);
  }

  static Future<void> comprovanteCaixaFechamento({
    String datainicial = '',
    String datafinal = '',
    String tipodefechamentocaixa = '',
    ModeloDestinoImpressao? destinoImpressaoCaixa,
  }) async {
    // ComprovanteCaixaFechamento(
    //   datainicial,
    //   datafinal,
    //   tipodefechamentocaixa,
    //   destinoImpressaoCaixa,
    // ).call();
  }

  static Future<void> comprovanteCaixaMovimento({
    String tipomovimento = '',
    ModeloDestinoImpressao? destinoImpressaoCaixa,
  }) async {
    // ComprovanteCaixaMovimento(
    //   tipomovimento,
    //   destinoImpressaoCaixa,
    // ).call();
  }

  static void comprovanteDoEntregador({
    List<Modelowordprodutos> produtos = const [],
    List<ModeloNomeLancamento> nomelancamento = const [],
    String somaValorHistorico = '',
    String celularEmpresa = '',
    String cnpjEmpresa = '',
    String enderecoEmpresa = '',
    String nomeEmpresa = '',
    String total = '',
    String permanencia = '',
    String nomeCliente = '',
    String celularCliente = '',
    String enderecoCliente = '',
    String valortroco = '0',
    String valorentrega = '0',
    String numeroPedido = '0',
    String tipodeentrega = '0',
    String numeroCliente = '',
    String bairroCliente = '',
    String complementoCliente = '',
    String cidadeCliente = '',
    bool imprimirSomenteLocal = false,
    bool enviarDeVolta = true,
  }) {
    var server = Modular.get<Server>();
    var usuario = Modular.get<UsuarioProvedor>();

    for (var element in produtos) {
      element.quantidadeController = null;
    }

    if (server.connected && enviarDeVolta == true) {
      if (produtos.isNotEmpty) {
        server.write(jsonEncode({
          'tipo': TipoCardapio.delivery.nome,
          'tipoImpressao': '3',
          'nomeConexao': usuario.usuario?.nome ?? 'Sem Nome',
          'produtos': produtos.map((e) => e.toMap()).toList(),
          'nomelancamento': nomelancamento.map((e) => e.toMap()).toList(),
          'somaValorHistorico': somaValorHistorico,
          'celularEmpresa': celularEmpresa,
          'cnpjEmpresa': cnpjEmpresa,
          'enderecoEmpresa': enderecoEmpresa,
          'nomeEmpresa': nomeEmpresa,
          'total': total,
          'permanencia': permanencia,
          'valorentrega': valorentrega,
          'numeroPedido': numeroPedido,
          'tipodeentrega': tipodeentrega,
          'nomeCliente': nomeCliente,
          'celularCliente': celularCliente,
          'enderecoCliente': enderecoCliente,
          'valortroco': valortroco,
          'numeroCliente': numeroCliente,
          'bairroCliente': bairroCliente,
          'complementoCliente': complementoCliente,
          'cidadeCliente': cidadeCliente,
          'nomeUsuario': usuario.usuario?.nome ?? '',
          'idEmpresa': usuario.usuario?.empresa ?? '0',
          'idUsuario': usuario.usuario?.id ?? '1',
          'enviarDeVolta': enviarDeVolta,
        }));
      }
    }
  }

  static void comprovanteDeConsumo({
    List<Modelowordprodutos> produtos = const [],
    List<ModeloNomeLancamento> nomelancamento = const [],
    String somaValorHistorico = '',
    String celularEmpresa = '',
    String cnpjEmpresa = '',
    String enderecoEmpresa = '',
    String nomeEmpresa = '',
    String numeroPedido = '',
    String total = '',
    String local = '',
    String permanencia = '',
    String valorentrega = '',
    String tipodeentrega = '',
    bool imprimirSomenteLocal = false,
    bool enviarDeVolta = true,
  }) async {
    var server = Modular.get<Server>();
    var usuario = Modular.get<UsuarioProvedor>();

    for (var element in produtos) {
      element.quantidadeController = null;
    }

    if (server.connected && enviarDeVolta == true) {
      if (produtos.isNotEmpty) {
        server.write(jsonEncode({
          'tipo': TipoCardapio.delivery.nome,
          'tipoImpressao': '2',
          'nomeConexao': usuario.usuario?.nome ?? 'Sem Nome',
          'produtos': produtos.map((e) => e.toMap()).toList(),
          'nomelancamento': nomelancamento.map((e) => e.toMap()).toList(),
          'somaValorHistorico': somaValorHistorico,
          'celularEmpresa': celularEmpresa,
          'cnpjEmpresa': cnpjEmpresa,
          'enderecoEmpresa': enderecoEmpresa,
          'nomeEmpresa': nomeEmpresa,
          'numeroPedido': numeroPedido,
          'total': total,
          'local': local,
          'permanencia': permanencia,
          'valorentrega': valorentrega,
          'tipodeentrega': tipodeentrega,
          'nomeUsuario': usuario.usuario?.nome ?? '',
          'idEmpresa': usuario.usuario?.empresa ?? '0',
          'idUsuario': usuario.usuario?.id ?? '1',
          'enviarDeVolta': enviarDeVolta,
        }));
      }
    }
  }
}
