import 'package:intl/intl.dart';

class Temporizador {
  int converterParaSegundo(String value) {
    final tempo = value.split(':');

    final duracao = Duration(hours: int.parse(tempo[0]), minutes: int.parse(tempo[1]), seconds: int.parse(tempo[2]));

    String hora = duracao.inHours.toString().padLeft(0, '2');
    String minuto = duracao.inMinutes.remainder(60).toString().padLeft(2, '0');
    String segungo = duracao.inSeconds.remainder(60).toString().padLeft(2, '0');

    return (int.parse(hora) * 60 * 60 + int.parse(minuto) * 60 + int.parse(segungo));
  }

  // int converterDataParaSegundo(String value) {
  //   DateTime dataAbertura = DateTime.parse(value);
  //   DateTime dataAtual = DateTime.now();

  //   int diferencaEmDias = (dataAtual.difference(dataAbertura).inDays - 1) * 24;

  //   return converterParaSegundo('$diferencaEmDias:00:00');
  // }

  int retornarDiferenca(int horaCadastro, int horaAtual) {
    late final int diferenca;

    if (horaCadastro >= horaAtual) {
      diferenca = horaCadastro - horaAtual;
    } else {
      diferenca = horaAtual - horaCadastro;
    }

    return diferenca;
  }

  String converterParaHora(seconds) {
    int p1 = seconds % 60;
    int p2 = seconds ~/ 60;
    int p3 = p2 % 60;

    p2 = p2 ~/ 60;

    final duracao = Duration(hours: p2, minutes: p3, seconds: p1);

    String hora = duracao.inHours.toString().padLeft(0, '2');
    String minuto = duracao.inMinutes.remainder(60).toString().padLeft(2, '0');
    String segundo = duracao.inSeconds.remainder(60).toString().padLeft(2, '0');

    return ('$hora:$minuto:$segundo');
  }

  String main(
    String hora,
    // String data,
  ) {
    final horaCadastro = converterParaSegundo(hora);
    // final dataCadastro = converterDataParaSegundo(data);
    final horaAtual = converterParaSegundo(DateFormat.Hms().format(DateTime.now()));

    // final diferenca = retornarDiferenca(horaCadastro + dataCadastro, horaAtual);
    final diferenca = retornarDiferenca(horaCadastro, horaAtual);

    final horaFormatada = converterParaHora(diferenca);

    return horaFormatada;
  }
}
