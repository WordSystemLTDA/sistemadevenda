import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'banco_local.dart';
import 'cache_consultas.dart';

class Sincronizador extends ChangeNotifier {
  static Sincronizador? instancia;
  final DioCliente api;
  final UsuarioProvedor usuario;
  final Server socket;
  final BancoLocal banco;
  Timer? _timer;
  Future<void>? _emAndamento;
  Future<void>? _enviando;
  final revisaoCatalogo = ValueNotifier<int>(0);
  Future<void>? _configurando;
  String escopo = '';
  String servidor = '';
  String destino = '';
  String? erro;
  bool online = false;
  bool catalogoPronto = false;
  bool _descartado = false;
  bool _solicitada = false;
  DateTime? ultimaAtualizacao;
  DateTime? _ultimoCatalogo;
  List<Map<String, Object?>> pendencias = [];
  void Function()? aoAtualizarTelas;

  Sincronizador(this.api, this.usuario, this.socket, {BancoLocal? banco})
      : banco = banco ?? BancoLocal.instancia!;

  bool get sincronizando => _emAndamento != null;
  int get conflitos => pendencias.where((e) => e['estado'] == 'conflito').length;

  void iniciar() {
    instancia = this;
    usuario.addListener(_sessaoMudou);
    socket.addListener(_socketMudou);
    _timer ??= Timer.periodic(const Duration(seconds: 15), (_) => solicitar());
    solicitar();
  }

  void _sessaoMudou() {
    // Invalida imediatamente as respostas em voo da conta anterior.
    escopo = '';
    api.cache?.escopo = '';
    pendencias = [];
    online = false;
    erro = null;
    catalogoPronto = false;
    _notificar();
    solicitar();
  }
  bool _socketConectado = false;
  void _socketMudou() {
    if (socket.connected && !_socketConectado) solicitar();
    _socketConectado = socket.connected;
  }

  void solicitar() {
    if (_descartado) return;
    _solicitada = true;
    if (_emAndamento == null) unawaited(sincronizar());
  }

  Future<void> configurar() => _configurando ??= _configurar().whenComplete(() {
    _configurando = null;
  });

  Future<void> _configurar() async {
    final conta = usuario.usuario;
    if (conta == null) {
      escopo = '';
      api.cache?.escopo = '';
      pendencias = [];
      return;
    }
    final url = (await Apis().getConexao()).servidor;
    final conexao = await ConfigSharedPreferences().getConexao();
    if (!identical(conta, usuario.usuario) || _descartado) return;
    final novo = BancoLocal.escopo(url, conta.empresa ?? '', conta.id ?? '');
    if (novo == escopo) return;
    escopo = novo;
    servidor = url;
    destino = conexao == null ? '' : '${conexao.servidor}:${conexao.porta}';
    banco.servidor = url;
    await banco.migrarPreferencia(ArmazenamentoCarrinhos.chavePreferencias,
        banco.chaveCarrinhos);
    if (!identical(conta, usuario.usuario) || _descartado) return;
    api.cache?.escopo = escopo;
    api.cache?.servidor = servidor;
    api.cache?.empresa = conta.empresa ?? '';
    _ultimoCatalogo = null;
    catalogoPronto = await banco.ler('catalogo:$escopo') != null;
    pendencias = await banco.operacoes(escopo);
    _notificar();
  }

  Future<void> guardarPedido({
    required ContextoCarrinho contexto,
    required List<Modelowordprodutos> itens,
    required String idMesa,
    required String idComanda,
    required String idCliente,
    required List<String> impressoes,
    bool recorrentes = false,
  }) async {
    await configurar();
    if (escopo.isEmpty || contexto.empresa != usuario.usuario?.empresa ||
        !['mesa', 'comanda'].contains(contexto.tipo)) {
      throw StateError('O atendimento nao pertence a esta conexao.');
    }
    final estadoSalvo = await banco.ler('estado:$escopo');
    final atendimento = estadoSalvo == null ? null :
        (jsonDecode(estadoSalvo)['atendimentos'] as Map?)?[contexto.idAtendimento];
    if (atendimento == null || atendimento['versao'] == null) {
      throw StateError('Aguarde a primeira sincronizacao deste atendimento.');
    }
    await ArmazenamentoCarrinhos.instancia.finalizarDuravel(
      escopo: escopo, contexto: contexto, itens: itens,
      dados: {
        'produtos': itens.map((e) => e.toMap()).toList(),
        'id_comanda_pedido': contexto.idAtendimento,
        'versao_atendimento': atendimento['versao'],
        'id_comanda': idComanda, 'id_mesa': idMesa,
        'tipo': contexto.tipo, 'id_cliente': idCliente,
        'empresa': contexto.empresa, 'id_usuario': usuario.usuario!.id,
      },
      impressoes: impressoes, destino: destino, recorrentes: recorrentes,
    );
    pendencias = await banco.operacoes(escopo);
    _notificar();
    unawaited(enviarPendentes());
  }

  Future<void> sincronizar() {
    if (_descartado) return Future.value();
    _solicitada = false;
    return _emAndamento ??= _sincronizar().whenComplete(() {
      _emAndamento = null;
      _notificar();
      if (_solicitada && !_descartado) solicitar();
    });
  }

  Options _opcoes(String url) => Options(
    extra: {'semCache': true, 'servidorFixo': url},
    sendTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  );

  Future<void> enviarPendentes() => _enviando ??= () async {
    try {
      await configurar();
      if (escopo.isNotEmpty) await _enviarPendentes(escopo, servidor);
    } on DioException catch (e) {
      if (CacheConsultas.falhaDeConexao(e)) online = false;
      else erro = 'Nao foi possivel enviar os pedidos. Verifique o servidor.';
    } catch (_) {
      erro = 'O envio ficou pendente. Os pedidos continuam salvos.';
    } finally {
      await _recarregarPendencias();
      _enviando = null;
      _notificar();
    }
  }();

  Future<void> _sincronizar() async {
    String? alvo;
    try {
      await configurar();
      if (escopo.isEmpty) return;
      alvo = escopo;
      final url = servidor;
      final empresa = usuario.usuario!.empresa;
      final idUsuario = usuario.usuario!.id;
      final estado = await api.cliente.get('sincronizacao/estado.php',
          queryParameters: {'empresa': empresa, 'id_usuario': idUsuario},
          options: _opcoes(url));
      if (alvo != escopo || usuario.usuario == null) return;
      if (estado.data is! Map || estado.data['protocolo'] != 1) {
        throw StateError('O servidor precisa da atualizacao de sincronizacao.');
      }
      online = true;
      erro = null;
      api.cache?.confirmarConexao();
      await banco.gravar('estado:$alvo', jsonEncode(estado.data));
      await enviarPendentes();
      if (alvo != escopo || usuario.usuario == null) return;
      await _atualizarConsultas(alvo, url, empresa!, idUsuario!);
      if (alvo != escopo) return;
      ultimaAtualizacao = DateTime.now();
      aoAtualizarTelas?.call();
      if (_ultimoCatalogo == null ||
          DateTime.now().difference(_ultimoCatalogo!) > const Duration(minutes: 2)) {
        await _carregarCatalogo(alvo, url, empresa, idUsuario);
      }
      await socket.processarImpressoesPendentes();
    } on DioException catch (e) {
      if (alvo != escopo) return;
      online = false;
      if (!CacheConsultas.falhaDeConexao(e)) {
        erro = e.response?.statusCode == 401 || e.response?.statusCode == 403
            ? 'Acesso nao autorizado. Entre novamente.'
            : 'Nao foi possivel sincronizar. Verifique a atualizacao do servidor.';
      }
    } catch (e) {
      if (alvo != null && alvo != escopo) return;
      erro = e is StateError ? e.message.toString() : 'Nao foi possivel sincronizar.';
    } finally {
      await _recarregarPendencias();
      _notificar();
    }
  }

  Future<void> _recarregarPendencias() async {
    final alvo = escopo;
    if (alvo.isEmpty || _descartado) return;
    try {
      final itens = await banco.operacoes(alvo);
      if (alvo == escopo && !_descartado) pendencias = itens;
    } catch (_) {
      erro = 'Nao foi possivel acessar os pedidos salvos. Verifique o armazenamento do aparelho.';
    }
  }

  Future<void> arquivarConflito(String id) async {
    await banco.db.update('operacoes', {'estado': 'arquivado'},
        where: 'id = ? AND escopo = ? AND estado = ?',
        whereArgs: [id, escopo, 'conflito']);
    await _recarregarPendencias();
    _notificar();
  }

  Future<void> _enviarPendentes(String alvo, String url) async {
    final bloqueados = <String>{};
    for (final op in await banco.operacoes(alvo)) {
      if (_descartado || escopo != alvo || usuario.usuario == null) return;
      final id = op['id'] as String;
      final atendimento = op['atendimento'] as String;
      if (op['estado'] == 'conflito' || bloqueados.contains(atendimento)) {
        bloqueados.add(atendimento);
        continue;
      }
      if ((op['proxima'] as int) > DateTime.now().millisecondsSinceEpoch) {
        bloqueados.add(atendimento);
        continue;
      }
      if (op['estado'] != 'registrado') {
        final dados = jsonDecode(op['dados'] as String) as Map<String, dynamic>;
        final tentativas = (op['tentativas'] as int) + 1;
        await banco.atualizarOperacao(id, {'tentativas': tentativas});
        Response resposta;
        try {
          resposta = await api.cliente.post('sincronizacao/operacao.php',
              data: jsonEncode({'id_operacao': id, 'acao': op['acao'],
                'empresa': dados['empresa'], 'id_usuario': dados['id_usuario'],
                'dados': dados}), options: _opcoes(url));
        } on DioException catch (e) {
          if (e.response?.statusCode == 409 || e.response?.statusCode == 422) {
            final mensagem = e.response?.data;
            await banco.atualizarOperacao(id, {'estado': 'conflito',
              'erro': mensagem is Map ? mensagem['mensagem']?.toString() :
                  'O atendimento mudou. Confira este pedido com o responsavel.'});
            bloqueados.add(atendimento);
            continue;
          }
          await banco.atualizarOperacao(id, {
            'proxima': DateTime.now().add(Duration(
                seconds: (2 * (1 << tentativas.clamp(0, 5))).clamp(2, 60)))
                .millisecondsSinceEpoch,
          });
          rethrow;
        }
        final resultado = resposta.data;
        // Exige o protocolo e o mesmo recibo, inclusive depois de resposta perdida.
        if (resultado is! Map || resultado['protocolo'] != 1 ||
            resultado['id_operacao'] != id || resultado['sucesso'] != true) {
          throw StateError('O servidor nao confirmou o pedido com seguranca.');
        }
        await banco.atualizarOperacao(id, {'estado': 'registrado',
          'resposta': jsonEncode(resultado), 'erro': null, 'proxima': 0});
      }
      if (alvo != escopo || usuario.usuario == null) return;
      final mensagens = List<String>.from(jsonDecode(op['impressoes'] as String));
      // O comprovante so entra na fila depois do commit confirmado no servidor.
      await socket.filaImpressao.registrar(mensagens, servidor: op['destino'] as String);
      await banco.atualizarOperacao(id, {'estado': 'concluido', 'erro': null});
      socket.write(jsonEncode({'tipo':
          jsonDecode(op['dados'] as String)['tipo'] == 'mesa' ? 'Mesa' : 'Comanda'}));
      await socket.processarImpressoesPendentes();
    }
  }

  Future<void> _atualizarConsultas(
      String alvo, String url, String empresa, String idUsuario) async {
    for (final rota in ['mesas/listar.php', 'comandas/listar.php',
      'categorias/listar.php', 'config_bigchef/listar.php',
      'comandas/listar_clientes.php', 'comandas/listar_mesas.php']) {
      if (alvo != escopo) return;
      final resposta = await api.cliente.get(rota,
          queryParameters: {'empresa': empresa,
            if (!['categorias/listar.php', 'config_bigchef/listar.php'].contains(rota)) 'pesquisa': ''},
          options: _opcoes(url));
      if (resposta.data is! List && resposta.data is! Map) {
        throw StateError('Lista invalida recebida do servidor.');
      }
      await banco.guardarConsulta(alvo, CacheConsultas.chave(resposta.requestOptions), resposta.data);
      if (rota == 'mesas/listar.php' || rota == 'comandas/listar.php') {
        final tipo = rota.startsWith('mesas/') ? 'Mesa' : 'Comanda';
        final campo = tipo == 'Mesa' ? 'mesas' : 'comandas';
        for (final grupo in resposta.data as List) {
          for (final recurso in (grupo[campo] as List? ?? [])) {
            final id = recurso['idComandaPedido']?.toString() ?? '';
            if (id.isEmpty || id == '0' || alvo != escopo) continue;
            for (final mostrar in ['Não', 'Sim']) {
              final detalhe = await api.cliente.get('cardapio/listar_por_id.php',
                queryParameters: {'id': id, 'codigoQrcode': 'null', 'empresa': empresa,
                  'id_usuario': idUsuario, 'tipo': tipo, 'mostrar_itens': mostrar},
                options: _opcoes(url));
              if (detalhe.data is Map && detalhe.data['id']?.toString() == id) {
                await banco.guardarConsulta(alvo, CacheConsultas.chave(detalhe.requestOptions), detalhe.data);
              }
            }
          }
        }
      }
    }
  }

  Future<void> _carregarCatalogo(
      String alvo, String url, String empresa, String idUsuario) async {
    final produtos = <Map<String, dynamic>>[];
    for (var pagina = 1; ; pagina++) {
      if (alvo != escopo || _descartado) return;
      final resposta = await api.cliente.get('produtos/listar_por_categoria.php',
          queryParameters: {'categoria': '0', 'empresa': empresa,
            'id_usuario': idUsuario, 'pagina': pagina}, options: _opcoes(url));
      if (resposta.data is! List) throw StateError('Cardapio invalido.');
      final itens = List<Map<String, dynamic>>.from(resposta.data as List);
      produtos.addAll(itens);
      if (itens.length < 15) break;
    }
    final detalhes = <String, dynamic>{};
    for (final produto in produtos) {
      final tamanhos = <String>{'0',
        ...(produto['tamanhosPizza'] as List? ?? []).map((t) => t['id'].toString())};
      for (final tamanho in tamanhos) {
        if (alvo != escopo || _descartado) return;
        final resposta = await api.cliente.get('produtos/listar_por_id.php',
          queryParameters: {'id': produto['id'], 'empresa': empresa,
            'id_usuario': idUsuario, 'id_tamanhos_pizza': tamanho}, options: _opcoes(url));
        if (resposta.data is! Map || resposta.data['id'] != produto['id']) {
          throw StateError('Nao foi possivel preparar todas as opcoes do cardapio.');
        }
        detalhes['${produto['id']}:$tamanho'] = resposta.data;
        if (tamanho == '0') detalhes['${produto['id']}:'] = resposta.data;
      }
    }
    if (alvo != escopo) return;
    final catalogo = jsonEncode({'produtos': produtos, 'detalhes': detalhes});
    final mudou = await banco.ler('catalogo:$alvo') != catalogo;
    await banco.db.transaction((tx) async {
      await BancoLocal.gravarDocumento(tx, 'catalogo:$alvo', catalogo);
      await tx.delete('consultas', where: 'escopo = ? AND chave LIKE ?',
          whereArgs: [alvo, '["produtos/%']);
    });
    _ultimoCatalogo = DateTime.now();
    catalogoPronto = true;
    if (mudou) revisaoCatalogo.value++;
    aoAtualizarTelas?.call();
  }

  Future<void> tentarNovamente() async {
    for (final op in await banco.operacoes(escopo)) {
      if (op['estado'] != 'conflito') await banco.atualizarOperacao(op['id'] as String, {'proxima': 0});
    }
    await sincronizar();
    await enviarPendentes();
  }

  void _notificar() { if (!_descartado) notifyListeners(); }

  @override
  void dispose() {
    _descartado = true;
    _timer?.cancel();
    usuario.removeListener(_sessaoMudou);
    socket.removeListener(_socketMudou);
    if (identical(instancia, this)) instancia = null;
    revisaoCatalogo.dispose();
    super.dispose();
  }
}
