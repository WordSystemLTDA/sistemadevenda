import 'dart:convert';

import 'package:app/src/essencial/api/socket/client.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_nome_lancamento.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:flutter_modular/flutter_modular.dart';

class Impressao {
  static Future<bool> enviarImpressao({
    List<ModeloNomeLancamento> nomelancamento = const [],
    List<ModeloProduto> produtos = const [],
    TipoCardapio tipo = TipoCardapio.balcao,
    String tipoImpressao = '1',
    String numeroPedido = '',
    String nomeCliente = '',
    String nomeEmpresa = '',
    String comanda = '',
    String permanencia = '',
    String somaValorHistorico = '',
    String celularEmpresa = '',
    String cnpjEmpresa = '',
    String enderecoEmpresa = '',
    String total = '',
    String local = '',
    String valorentrega = '',
    String tipodeentrega = '',
    String celularCliente = '',
    String enderecoCliente = '',
    String valortroco = '',
    String numeroCliente = '',
    String bairroCliente = '',
    String complementoCliente = '',
    String cidadeCliente = '',
  }) async {
    var cliente = Modular.get<Client>();
    var usuario = Modular.get<UsuarioProvedor>();

    final ConfigSharedPreferences config = ConfigSharedPreferences();
    var conexao = await config.getConexao();

    if (cliente.connected == false) {
      var sucessoConexao = await cliente.connect(conexao!.servidor, int.parse(conexao.porta));

      if (sucessoConexao == false) {
        return false;
      }
    }

    // pedido
    if (tipoImpressao == '1') {
      cliente.write(jsonEncode({
        'tipo': tipo.nome,
        'tipoImpressao': tipoImpressao,
        'nomeConexao': usuario.usuario!.nome ?? 'Sem Nome',
        'produtos': produtos.map((e) => e.toMap()).toList(),
        'comanda': comanda,
        'numeroPedido': numeroPedido,
        'nomeCliente': nomeCliente,
        'nomeEmpresa': nomeEmpresa,
        'tipodeentrega': tipodeentrega,
        'local': local,
      }));

      // conta
    } else if (tipoImpressao == '2') {
      cliente.write(jsonEncode({
        'tipo': tipo.nome,
        'tipoImpressao': tipoImpressao,
        'nomeConexao': usuario.usuario!.nome ?? 'Sem Nome',
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
      }));
    } else if (tipoImpressao == '3') {
      cliente.write(jsonEncode({
        'tipo': tipo.nome,
        'tipoImpressao': tipoImpressao,
        'nomeConexao': usuario.usuario!.nome ?? 'Sem Nome',
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
      }));
    }

    return true;
  }
}
