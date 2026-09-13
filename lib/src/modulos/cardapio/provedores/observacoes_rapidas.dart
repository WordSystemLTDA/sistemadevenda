import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show StringCharacters;
import 'package:shared_preferences/shared_preferences.dart';

class ObservacoesRapidas extends ChangeNotifier {
  static final doAparelho = ObservacoesRapidas();
  static const chave = 'observacoes_rapidas_aparelho_v1';
  static const limiteCaracteres = 200;
  static const padroes = [
    'Sem cebola',
    'Sem alface',
    'Sem tomate',
    'Sem maionese',
    'Bem passado',
    'Mal passado',
    'Caprichar',
    'Embalar separado',
  ];

  Future<void>? _gravacoes;

  Future<List<String>> listar() async {
    await _gravacoes;
    final prefs = await SharedPreferences.getInstance();
    return List.of(prefs.getStringList(chave) ?? padroes);
  }

  Future<void> salvar(String texto, {String? anterior}) => _alterar((lista) {
        final novo = texto.trim();
        if (novo.isEmpty) throw const FormatException('Digite uma observação.');
        if (novo.characters.length > limiteCaracteres) {
          throw const FormatException('Use até 200 caracteres.');
        }
        if (lista.any((item) =>
            item != anterior && item.toLowerCase() == novo.toLowerCase())) {
          throw const FormatException('Essa observação já está cadastrada.');
        }
        if (anterior == null) {
          lista.add(novo);
        } else {
          final index = lista.indexOf(anterior);
          if (index < 0) {
            throw const FormatException(
                'Essa observação não está mais na lista.');
          }
          lista[index] = novo;
        }
      });

  Future<void> excluir(String texto) =>
      _alterar((lista) => lista.remove(texto));

  Future<void> _alterar(void Function(List<String>) alterar) {
    // Serializa gravacoes das telas que compartilham as mesmas preferencias.
    final resultado = (_gravacoes ?? Future<void>.value()).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      final lista = List.of(prefs.getStringList(chave) ?? padroes);
      alterar(lista);
      try {
        if (!await prefs.setStringList(chave, lista)) {
          throw StateError('Não foi possível salvar neste aparelho.');
        }
      } catch (_) {
        await prefs.reload();
        rethrow;
      }
      notifyListeners();
    });
    final gravacao = resultado.then<void>((_) {}, onError: (Object _) {});
    _gravacoes = gravacao;
    gravacao.then((_) {
      if (identical(_gravacoes, gravacao)) _gravacoes = null;
    });
    return resultado;
  }
}
