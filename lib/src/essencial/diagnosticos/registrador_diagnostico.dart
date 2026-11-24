import 'dart:async';
import 'dart:developer' as developer;
import 'servico_diagnostico.dart';

/// Conserva o log do desenvolvedor e inclui falhas tratadas no historico.
void log(String message,
    {DateTime? time,
    int? sequenceNumber,
    int level = 0,
    String name = '',
    Zone? zone,
    Object? error,
    StackTrace? stackTrace}) {
  developer.log(message,
      time: time,
      sequenceNumber: sequenceNumber,
      level: level,
      name: name,
      zone: zone,
      error: error,
      stackTrace: stackTrace);
  if (error != null) {
    ServicoDiagnostico.instancia.registrar(
        origem: name.isEmpty ? 'servicos' : name,
        mensagem: message,
        pilha: stackTrace,
        dados: {'erro': error.toString()});
  } else {
    ServicoDiagnostico.instancia
        .contexto(origem: name.isEmpty ? 'servicos' : name, mensagem: message);
    ServicoDiagnostico.instancia.console(message);
  }
}
