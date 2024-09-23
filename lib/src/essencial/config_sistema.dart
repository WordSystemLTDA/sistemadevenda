import 'package:flutter/material.dart';

class ConfigSistema {
  static const double fontLabelModal = 12;
  static const double espacoAlturaInput = 4;
  static const double espacoLateralInput = 10;

  static const double espacoLateralInputPdv = 10;
  static const double fontLabelModalPdv = 12;
  static const double alturaInputPdv = 30;

  static const double alturaMenuSuperior = 30;
  // static Color? corMenuSuperior = Colors.grey[300];

  static Color? corMenuSuperior(BuildContext context) {
    var temaEscuro = Theme.of(context).brightness == Brightness.dark;

    if (temaEscuro) {
      return Colors.grey[800];
    } else {
      return Colors.grey[300];
    }
  }

  static Color? corStatus(String status) {
    if (status == 'Pendente') {
      return Colors.red;
    } else if (status == 'Aguardando') {
      return Colors.grey;
    } else if (status == 'Confirmado') {
      return Colors.tealAccent;
    } else if (status == 'Concluída') {
      return Colors.blue;
    } else if (status == 'Andamento') {
      return const Color.fromARGB(255, 168, 213, 116);
    } else if (status == 'Finalizado') {
      return Colors.green;
    } else if (status == 'Cancelada') {
      return Colors.yellow[800];
    }

    return null;
  }

  static String formatarHora(Duration duration) {
    int days = duration.inDays;
    int hours = duration.inHours % 24;
    int minutes = duration.inMinutes % 60;
    int seconds = duration.inSeconds % 60;

    if (days > 0) {
      return "$days ${days == 1 ? 'dia' : 'dias'} $hours ${hours == 1 ? 'hora' : 'horas'}";
    } else if (hours > 0) {
      return "$hours ${hours == 1 ? 'hora' : 'horas'} $minutes min";
    } else {
      return "$minutes min $seconds seg";
    }
  }
}
