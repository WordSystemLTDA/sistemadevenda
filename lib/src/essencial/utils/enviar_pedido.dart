import 'dart:convert';
import 'dart:developer';

import 'package:app/src/essencial/api/socket/client.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_nome_lancamento.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:flutter_modular/flutter_modular.dart';

class EnviarPedido {
  static void enviarPedido({
    String tipo = '1',
    String nomeTitulo = '',
    String numeroPedido = '',
    String nomeCliente = '',
    String nomeEmpresa = '',
    List<ModeloProduto> produtosNovos = const [],
    List<ModeloProduto> produtos = const [],
    String dataAbertura = '',
    List<ModeloNomeLancamento> nomelancamento = const [],
    String somaValorHistorico = '',
    String celularEmpresa = '',
    String cnpjEmpresa = '',
    String enderecoEmpresa = '',
    String total = '',
    String local = '',
    String valorentrega = '',
  }) async {
    var cliente = Modular.get<Client>();

    final ConfigSharedPreferences config = ConfigSharedPreferences();
    var conexao = await config.getConexao();

    if (cliente.connected == false) {
      await cliente.connect(conexao!.servidor, 9980).then((value) {
        if (value) {
          log('conectou');
        } else {
          log('não conectou');
        }
      });
    }

    log('mandou mensagem');

    // pedido
    if (tipo == '1') {
      cliente.write(jsonEncode({
        'tipo': tipo,
        'nomeTitulo': nomeTitulo,
        'numeroPedido': numeroPedido,
        'nomeCliente': nomeCliente,
        'nomeEmpresa': nomeEmpresa,
        'produtosNovos': produtosNovos.toList(),
      }));

      // conta
    } else if (tipo == '2') {
      cliente.write(jsonEncode({
        'tipo': tipo,
        'produtos': produtos,
        'celularEmpresa': celularEmpresa,
        'nomelancamento': nomelancamento,
        'somaValorHistorico': somaValorHistorico,
        'cnpjEmpresa': cnpjEmpresa,
        'enderecoEmpresa': enderecoEmpresa,
        'nomeEmpresa': nomeEmpresa,
        'valorTotal': total,
        'numeroPedido': numeroPedido,
        'local': local,
        'dataAbertura': dataAbertura,
      }));
    }

    cliente.disconnect();

    // final channel = WebSocketChannel.connect(
    //   Uri.parse('ws://192.168.2.115:9980/'),
    // );

    // await channel.ready.then((_) {
    //   channel.sink.add('Atualizou');
    //   channel.sink.close();
    // }).onError((error, stackTrace) {
    //   print('Erro ao conectar ao PHP');
    // });
  }
}
