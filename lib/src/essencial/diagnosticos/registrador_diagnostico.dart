import 'dart:async';
import 'dart:developer' as developer;
import 'servico_diagnostico.dart';

/// Conserva o log do desenvolvedor e inclui falhas tratadas no historico.
void log(String message, {DateTime? time, int? sequenceNumber, int level = 0, String name = '', Zone? zone, Object? error, StackTrace? stackTrace}) {
  developer.log(message, time: time, sequenceNumber: sequenceNumber, level: level, name: name, zone: zone, error: error, stackTrace: stackTrace);
  try {
    if (error != null || stackTrace != null || level >= 900) {
      ServicoDiagnostico.instancia.registrar(
          origem: name.isEmpty ? 'servicos' : name,
          mensagem: message,
          nivel: error != null || stackTrace != null || level >= 1000 ? 'error' : 'warning',
          pilha: stackTrace ?? StackTrace.current,
          dados: {'nivel_log': level, if (error != null) 'erro': error.toString()});
    } else {
      ServicoDiagnostico.instancia.contexto(origem: name.isEmpty ? 'servicos' : name, mensagem: message);
      ServicoDiagnostico.instancia.console(message, origem: name.isEmpty ? 'servicos' : name);
    }
  } catch (_) {/* Uma falha no diagnóstico não interrompe a operação. */}
}
