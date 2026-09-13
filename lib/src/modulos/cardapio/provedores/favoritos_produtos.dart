import 'dart:async';

import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda apenas preferencias, nunca precos ou montagens de pedidos.
class FavoritosProdutos extends ChangeNotifier {
  FavoritosProdutos(this.usuarios, {Future<String> Function()? servidor})
      : obterServidor =
            servidor ?? (() async => (await Apis().getConexao()).servidor) {
    usuarios.addListener(_mudouUsuario);
  }

  final UsuarioProvedor usuarios;
  final Future<String> Function() obterServidor;
  Set<String> _ids = {};
  Set<String> get ids => Set.unmodifiable(_ids);
  String? _chave;
  String? erro;
  bool carregando = false;
  bool _descartado = false;
  int _revisao = 0;
  Future<void> _gravacoes = Future.value();
  bool get disponivel => _chave != null && !carregando && !_descartado;
  bool contem(String id) => _ids.contains(id);

  void _mudouUsuario() {
    _chave = null;
    _ids = {};
    unawaited(carregar());
  }

  Future<void> carregar() async {
    if (_descartado) return;
    final revisao = ++_revisao;
    final usuario = usuarios.usuario;
    carregando = true;
    erro = null;
    notifyListeners();
    try {
      await _gravacoes;
      final empresa = usuario?.empresa ?? '';
      final operador = usuario?.id ?? '';
      final servidor = await obterServidor();
      final chave = empresa.isEmpty || operador.isEmpty || servidor.isEmpty
          ? null
          : 'favoritos_produtos:v1:${BancoLocal.escopo(servidor, empresa, operador)}';
      final prefs = await SharedPreferences.getInstance();
      final ids = chave == null ? <String>[] : prefs.getStringList(chave) ?? [];
      if (_descartado || revisao != _revisao) return;
      _chave = chave;
      _ids = ids.where((id) => id.trim().isNotEmpty).toSet();
    } catch (_) {
      if (_descartado || revisao != _revisao) return;
      _chave = null;
      _ids = {};
      erro = 'Não foi possível carregar os favoritos.';
    } finally {
      if (!_descartado && revisao == _revisao) {
        carregando = false;
        notifyListeners();
      }
    }
  }

  Future<bool> alternar(String id) {
    if (!disponivel || id.trim().isEmpty) return Future.value(false);
    final chave = _chave!;
    final revisao = _revisao;
    // Serializa toques rapidos para uma gravacao nao apagar a anterior.
    final resultado = _gravacoes.then((_) async {
      if (_descartado || revisao != _revisao) return false;
      try {
        final servidor = await obterServidor();
        final atual = usuarios.usuario;
        final chaveAtual =
            'favoritos_produtos:v1:${BancoLocal.escopo(servidor, atual?.empresa ?? '', atual?.id ?? '')}';
        if (chaveAtual != chave) {
          if (!_descartado && revisao == _revisao) {
            _chave = null;
            _ids = {};
          }
          throw StateError('A conexao mudou');
        }
        final prefs = await SharedPreferences.getInstance();
        if (_descartado || revisao != _revisao) return false;
        final novos = (prefs.getStringList(chave) ?? <String>[]).toSet();
        if (!novos.remove(id)) novos.add(id);
        if (!await prefs.setStringList(chave, novos.toList())) {
          throw StateError('Falha ao salvar preferencia');
        }
        if (_descartado || revisao != _revisao) return false;
        _ids = novos;
        erro = null;
        notifyListeners();
        return true;
      } catch (_) {
        if (!_descartado && revisao == _revisao) {
          erro = 'Não foi possível salvar o favorito. Tente novamente.';
          notifyListeners();
        }
        return false;
      }
    });
    _gravacoes = resultado.then((_) {});
    return resultado;
  }

  @override
  void dispose() {
    _descartado = true;
    _revisao++;
    usuarios.removeListener(_mudouUsuario);
    super.dispose();
  }
}
