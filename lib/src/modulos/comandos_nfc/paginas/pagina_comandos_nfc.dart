import 'package:app/src/essencial/utils/nfc.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/inicio/paginas/widgets/card_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';

class PaginaComandosNfc extends StatefulWidget {
  const PaginaComandosNfc({super.key});

  @override
  State<PaginaComandosNfc> createState() => _PaginaComandosNfcState();
}

class _PaginaComandosNfcState extends State<PaginaComandosNfc> {
  Future<void> abrirLeitorNFC(TipoCardapio tipo) async {
    // FlutterNfcKit.finish();

    try {
      var tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
        iosMultipleTagMessage: "Multiplas TAGS Encontradas!",
        iosAlertMessage: "Escaneie a sua TAG",
        readIso14443A: true,
      );

      if (tag.type == NFCTagType.mifare_ultralight) {
        var ndef = await FlutterNfcKit.readNDEFRecords();

        if (ndef.isEmpty) {
          FlutterNfcKit.finish(iosErrorMessage: 'Essa TAG não tem código Registrado.');
          return;
        }

        var payload = ndef.first.toString();
        var dataText = payload.indexOf('text=');
        var codigo = payload.substring(dataText + 5);

        final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();

        await servicoCardapio.listarIdCodigoQrcode(tipo, codigo).then((value) {
          if (value.sucesso == false) {
            FlutterNfcKit.finish(iosErrorMessage: 'Essa ${tipo.nome} não existe.');
            return;
          } else {
            FlutterNfcKit.finish();
          }

          Nfc.enviarComando(
            tipo: tipo,
            idComandaPedido: value.idComandaPedido,
            ocupado: value.ocupado,
            codigo: value.codigo,
            id: value.id,
            nome: value.nome,
          );
        });
      } else {
        FlutterNfcKit.finish(iosErrorMessage: 'Tipo de TAG não reconhecido: ${tag.type.name}');
        return;
      }
    } on PlatformException catch (e) {
      FlutterNfcKit.finish(iosErrorMessage: e.details);
    }
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.sizeOf(context);

    final double itemHeight = (size.height - 40) / 5;
    final double itemWidth = size.width / 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enviar Comandos NFC'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                childAspectRatio: (itemWidth / itemHeight),
                children: [
                  CardHome(
                    nome: 'Mesas',
                    icone: const Icon(Icons.table_bar_outlined, size: 40),
                    onPressed: () {
                      abrirLeitorNFC(TipoCardapio.mesa);
                    },
                  ),
                  CardHome(
                    nome: 'Comandas',
                    icone: const Icon(Icons.fact_check_outlined, size: 40),
                    onPressed: () {
                      abrirLeitorNFC(TipoCardapio.comanda);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
