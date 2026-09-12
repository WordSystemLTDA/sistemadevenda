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
import 'atendimentos_locais.dart';
import 'cache_consultas.dart';
import 'execucao_segundo_plano.dart';

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
  final Map<String, DateTime> _detalhesAtualizados = {};
  List<Map<String, Object?>> pendencias = [];
  void Function()? aoAtualizarTelas;

  Sincronizador(this.api, this.usuario, this.socket, {BancoLocal? banco})
      : banco = banco ?? BancoLocal.instancia!;

  bool get sincronizando => _emAndamento != null;
  int get conflitos =>
      pendencias.where((e) => e['estado'] == 'conflito').length;

  void iniciar() {
    instancia = this;
    usuario.addListener(_sessaoMudou);
    socket.addListener(_socketMudou);
    socket.aoAtualizarDados = _dadosMudaram;
    api.cache?.aoAtualizar = () => aoAtualizarTelas?.call();
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

  void _dadosMudaram(String tipo) {
    if (['Produto', 'Produtos', 'Cardapio', 'Categoria', 'Categorias']
        .contains(tipo)) {
      _ultimoCatalogo = null;
    }
    if (['Mesa', 'Comanda'].contains(tipo)) _detalhesAtualizados.clear();
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
    await banco.migrarPreferencia(
        ArmazenamentoCarrinhos.chavePreferencias, banco.chaveCarrinhos);
    if (!identical(conta, usuario.usuario) || _descartado) return;
    api.cache?.escopo = escopo;
    api.cache?.servidor = servidor;
    api.cache?.empresa = conta.empresa ?? '';
    _ultimoCatalogo = null;
    _detalhesAtualizados.clear();
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
    if (escopo.isEmpty ||
        contexto.empresa != usuario.usuario?.empresa ||
        !['mesa', 'comanda'].contains(contexto.tipo)) {
      throw StateError('O atendimento nao pertence a esta conexao.');
    }
    final alvo = escopo;
    final conta = usuario.usuario!;
    final destinoOriginal = destino;
    final abertura =
        await AtendimentosLocais(banco, alvo).abertura(contexto.idAtendimento);
    if (abertura != null &&
        ['conflito', 'arquivado'].contains(abertura['estado'])) {
      throw StateError('A abertura deste atendimento precisa de conferencia.');
    }
    final estadoSalvo = await banco.ler('estado:$alvo');
    final atendimento = estadoSalvo == null
        ? null
        : (jsonDecode(estadoSalvo)['atendimentos']
            as Map?)?[contexto.idAtendimento];
    final versao = await banco.ler('versao:$alvo:${contexto.idAtendimento}') ??
        atendimento?['versao'];
    if (versao == null && abertura == null) {
      throw StateError('Aguarde a primeira sincronizacao deste atendimento.');
    }
    if (alvo != escopo || !identical(conta, usuario.usuario)) {
      throw StateError('A conta mudou. Confira o carrinho antes de enviar.');
    }
    final origem = abertura == null ? null : AtendimentosLocais.dados(abertura);
    await ArmazenamentoCarrinhos.instancia.finalizarDuravel(
      escopo: alvo,
      contexto: contexto,
      itens: itens,
      dados: {
        'produtos': itens.map((e) => e.toMap()).toList(),
        'id_comanda_pedido': contexto.idAtendimento,
        'versao_atendimento': versao,
        if (abertura != null) 'id_abertura': abertura['id'],
        'id_comanda': origem?['id_comanda'] ?? idComanda,
        'id_mesa': origem?['id_mesa'] ?? idMesa,
        'tipo': origem?['tipo'] ?? contexto.tipo,
        'id_cliente': origem?['id_cliente'] ?? idCliente,
        'empresa': contexto.empresa,
        'id_usuario': conta.id,
      },
      impressoes: impressoes,
      destino: destinoOriginal,
      recorrentes: recorrentes,
    );
    await _recarregarPendencias();
    _notificar();
    unawaited(enviarPendentes());
  }

  Future<String> abrirAtendimento(
      {required String tipo,
      String idMesa = '0',
      String idComanda = '0',
      String idCliente = '0',
      String obs = ''}) async {
    await configurar();
    if (escopo.isEmpty) {
      throw StateError('Entre na sua conta para abrir o atendimento.');
    }
    final alvo = escopo;
    final conta = usuario.usuario!;
    final destinoOriginal = destino;
    idMesa = idMesa.isEmpty ? '0' : idMesa;
    idComanda = idComanda.isEmpty ? '0' : idComanda;
    idCliente = idCliente.isEmpty ? '0' : idCliente;
    if (!await prepararAberturasOffline()) {
      throw StateError(
          'Conecte uma vez ao servidor atualizado para preparar as aberturas offline.');
    }
    final estado = jsonDecode(await banco.ler('estado:$alvo') ?? '{}') as Map;
    final recursos = estado['recursos'] as Map? ?? {};
    final versoes = <String, String>{};
    for (final entrada in {'mesa': idMesa, 'comanda': idComanda}.entries) {
      if (entrada.value == '0') continue;
      final chave = '${entrada.key}:${entrada.value}';
      final recurso = recursos[chave] as Map?;
      if (recurso == null ||
          recurso['livre'] != true ||
          recurso['ativo'] != 'Sim') {
        throw StateError(
            'Esta mesa ou comanda nao esta livre na ultima atualizacao.');
      }
      versoes[chave] = recurso['versao'].toString();
    }
    final locais = AtendimentosLocais(banco, alvo);
    final nomeCliente = await locais.nomeCliente(idCliente);
    if (alvo != escopo || !identical(conta, usuario.usuario)) {
      throw StateError('A conta mudou. Abra o atendimento novamente.');
    }
    final recurso =
        recursos['$tipo:${tipo == 'mesa' ? idMesa : idComanda}'] as Map;
    final id = await locais.abrir({
      'tipo': tipo,
      'empresa': conta.empresa,
      'id_usuario': conta.id,
      'id_mesa': idMesa,
      'id_comanda': idComanda,
      'id_cliente': idCliente,
      'obs': obs,
      'recursos': versoes,
      'detalhe': {
        'nome': recurso['nome']?.toString() ?? '',
        'codigo': recurso['codigo']?.toString() ?? '',
        'idMesa': idMesa,
        'idComanda': idComanda,
        'idCliente': idCliente,
        'nomeMesa':
            (recursos['mesa:$idMesa'] as Map?)?['nome']?.toString() ?? '',
        'nomeCliente': nomeCliente,
        'observacaoDoPedido': obs,
        'dataAbertura': DateTime.now().toIso8601String(),
        'nomeEmpresa': conta.nomeEmpresa ?? '',
        'somaValorHistorico': '0',
        'nomelancamento': [],
        'valorentrega': '0',
      }
    }, destinoOriginal);
    await _recarregarPendencias();
    _notificar();
    aoAtualizarTelas?.call();
    unawaited(enviarPendentes());
    return id;
  }

  Future<bool> prepararAberturasOffline() async {
    await configurar();
    if (escopo.isEmpty) return false;
    final alvo = escopo;
    final conta = usuario.usuario!;
    final estado = jsonDecode(await banco.ler('estado:$alvo') ?? '{}') as Map;
    if (estado['abertura_offline'] == 1) return true;
    if (api.cache?.servidorDisponivel == false) return false;
    try {
      final resposta = await api.cliente.get('sincronizacao/estado.php',
          queryParameters: {'empresa': conta.empresa, 'id_usuario': conta.id},
          options: _opcoes(servidor));
      if (alvo != escopo || !identical(conta, usuario.usuario)) return false;
      if (resposta.data is Map && resposta.data['protocolo'] == 1) {
        await banco.gravar('estado:$alvo', jsonEncode(resposta.data));
        return resposta.data['abertura_offline'] == 1;
      }
      return false;
    } on DioException catch (e) {
      if (!CacheConsultas.falhaDeConexao(e)) rethrow;
      return false;
    }
  }

  Future<String> guardarVenda(
      {required ContextoCarrinho contexto,
      required List<Modelowordprodutos> itens,
      required Map<String, dynamic> dados,
      required List<String> impressoes}) async {
    await configurar();
    if (escopo.isEmpty ||
        contexto.empresa != usuario.usuario?.empresa ||
        contexto.tipo != 'balcao') {
      throw StateError('Venda sem conta ou carrinho valido.');
    }
    final alvo = escopo;
    final conta = usuario.usuario!;
    final destinoOriginal = destino;
    final id = BancoLocal.novoId();
    final estado = jsonDecode(await banco.ler('estado:$alvo') ?? '{}') as Map;
    if (!estado.containsKey('caixa_id')) {
      throw StateError(
          'Conecte uma vez ao servidor atualizado para preparar as vendas offline.');
    }
    if (alvo != escopo ||
        !identical(conta, usuario.usuario) ||
        dados['empresa'] != conta.empresa ||
        dados['id_usuario'] != conta.id) {
      throw StateError('A conta mudou. Confira a venda antes de finalizar.');
    }
    final payload = {...dados, 'caixa_id': estado['caixa_id']};
    await ArmazenamentoCarrinhos.instancia.finalizarDuravel(
        escopo: alvo,
        contexto: contexto,
        itens: itens,
        dados: payload,
        impressoes: impressoes,
        destino: destinoOriginal,
        acao: 'venda',
        idOperacao: id,
        atendimentoOperacao: 'venda-local:$id');
    await _recarregarPendencias();
    _notificar();
    unawaited(enviarPendentes());
    return 'venda-local:$id';
  }

  Future<void> guardarPagamentoVenda(
      String idVenda, Map<String, dynamic> dados) async {
    await configurar();
    final alvo = escopo;
    final conta = usuario.usuario;
    final destinoOriginal = destino;
    if (alvo.isEmpty || conta == null) {
      throw StateError('Entre na conta original da venda.');
    }
    final origem = (await banco.db.query('operacoes',
            where: 'escopo = ? AND atendimento = ? AND acao = ?',
            whereArgs: [alvo, idVenda, 'venda'],
            orderBy: 'criado, rowid',
            limit: 1))
        .firstOrNull;
    if (origem == null ||
        ['conflito', 'arquivado'].contains(origem['estado'])) {
      throw StateError('A venda original precisa de conferencia.');
    }
    if (alvo != escopo ||
        !identical(conta, usuario.usuario) ||
        dados['empresa'] != conta.empresa ||
        dados['id_usuario'] != conta.id) {
      throw StateError('A conta mudou. Confira a venda antes de finalizar.');
    }
    final original = AtendimentosLocais.dados(origem);
    final payload = {
      ...dados,
      'id_venda_origem': origem['id'],
      'caixa_id': original['caixa_id'],
      'produtos': []
    };
    await banco.db.insert('operacoes', {
      'id': BancoLocal.novoId(),
      'escopo': alvo,
      'atendimento': idVenda,
      'acao': 'venda',
      'estado': 'pendente',
      'dados': jsonEncode(payload),
      'impressoes': '[]',
      'destino': destinoOriginal,
      'criado': DateTime.now().millisecondsSinceEpoch,
    });
    await _recarregarPendencias();
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
          if (escopo.isNotEmpty) {
            await ExecucaoSegundoPlano.executar(
                () => _enviarPendentes(escopo, servidor));
          }
        } on DioException catch (e) {
          if (CacheConsultas.falhaDeConexao(e)) {
            online = false;
          } else {
            erro = 'Nao foi possivel enviar os pedidos. Verifique o servidor.';
          }
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
      for (final rota in [
        'listar_banco_pix',
        'listar_datas_vendas',
        'listar_bancos'
      ]) {
        if (alvo != escopo) return;
        final resposta = await api.cliente.get('tela_nfe_saida/$rota.php',
            queryParameters: rota == 'listar_bancos'
                ? {'id_empresa': empresa, 'id_usuario': idUsuario}
                : {'empresa': empresa},
            options: _opcoes(url));
        await banco.guardarConsulta(
            alvo, CacheConsultas.chave(resposta.requestOptions), resposta.data);
      }
      if (alvo != escopo) return;
      ultimaAtualizacao = DateTime.now();
      aoAtualizarTelas?.call();
      if (_ultimoCatalogo == null ||
          DateTime.now().difference(_ultimoCatalogo!) >
              const Duration(minutes: 2)) {
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
      erro = e is StateError
          ? e.message.toString()
          : 'Nao foi possivel sincronizar.';
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
      erro =
          'Nao foi possivel acessar os pedidos salvos. Verifique o armazenamento do aparelho.';
    }
  }

  Future<void> arquivarConflito(String id) async {
    await banco.db.transaction((tx) async {
      final operacao = (await tx.query('operacoes',
              where: 'id = ? AND escopo = ? AND estado = ?',
              whereArgs: [id, escopo, 'conflito']))
          .firstOrNull;
      if (operacao == null) return;
      await tx.update('operacoes', {'estado': 'arquivado'},
          where: 'id = ?', whereArgs: [id]);
      if (operacao['acao'] == 'abertura') {
        await tx.update(
            'operacoes',
            {
              'estado': 'conflito',
              'erro':
                  'A abertura original foi arquivada. Confira os produtos antes de arquivar.'
            },
            where: "escopo = ? AND atendimento = ? AND estado = 'pendente'",
            whereArgs: [escopo, operacao['atendimento']]);
      }
    });
    await _recarregarPendencias();
    _notificar();
  }

  Future<List<Map<String, dynamic>>> rascunhosBloqueados() async {
    final dados =
        jsonDecode(await banco.ler(banco.chaveCarrinhos) ?? '{}') as Map;
    return dados.values
        .whereType<Map>()
        .where((r) =>
            r['empresa'] == usuario.usuario?.empresa &&
            (r['encerrado'] == true || r['bloqueado'] == true) &&
            ((r['itens'] as List? ?? []).isNotEmpty ||
                (r['recorrentes'] as List? ?? []).isNotEmpty))
        .map((r) => Map<String, dynamic>.from(r))
        .toList();
  }

  Future<void> _enviarPendentes(String alvo, String url) async {
    final bloqueados = <String>{};
    for (final op in await banco.operacoes(alvo)) {
      if (_descartado || escopo != alvo || usuario.usuario == null) return;
      final id = op['id'] as String;
      final atendimento = op['atendimento'] as String;
      final dadosOriginais = AtendimentosLocais.dados(op);
      if (op['acao'] == 'venda' && dadosOriginais['id_venda_origem'] != null) {
        final origem = (await banco.db.query('operacoes',
                where: 'escopo = ? AND id = ?',
                whereArgs: [alvo, dadosOriginais['id_venda_origem']]))
            .firstOrNull;
        if (origem == null ||
            ['conflito', 'arquivado'].contains(origem['estado'])) {
          await banco.atualizarOperacao(id, {
            'estado': 'conflito',
            'erro':
                'A venda original nao foi confirmada. Confira este pagamento.'
          });
          bloqueados.add(atendimento);
          continue;
        }
        if (origem['estado'] != 'concluido') continue;
      }
      if (op['acao'] == 'produtos' && AtendimentosLocais.local(atendimento)) {
        final abertura =
            await AtendimentosLocais(banco, alvo).abertura(atendimento);
        if (abertura == null ||
            ['conflito', 'arquivado'].contains(abertura['estado'])) {
          await banco.atualizarOperacao(id, {
            'estado': 'conflito',
            'erro':
                'A abertura original nao foi confirmada. Confira este pedido.'
          });
          bloqueados.add(atendimento);
          continue;
        }
        if (abertura['estado'] != 'concluido') continue;
      }
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
              data: jsonEncode({
                'id_operacao': id,
                'acao': op['acao'],
                'empresa': dados['empresa'],
                'id_usuario': dados['id_usuario'],
                'dados': dados
              }),
              options: _opcoes(url));
        } on DioException catch (e) {
          if (e.response?.statusCode == 409 || e.response?.statusCode == 422) {
            final mensagem = e.response?.data;
            await banco.atualizarOperacao(id, {
              'estado': 'conflito',
              'erro': mensagem is Map
                  ? mensagem['mensagem']?.toString()
                  : 'O atendimento mudou. Confira este pedido com o responsavel.'
            });
            bloqueados.add(atendimento);
            continue;
          }
          await banco.atualizarOperacao(id, {
            'proxima': DateTime.now()
                .add(Duration(
                    seconds: (2 * (1 << tentativas.clamp(0, 5))).clamp(2, 60)))
                .millisecondsSinceEpoch,
          });
          rethrow;
        }
        final resultado = resposta.data;
        // Exige o protocolo e o mesmo recibo, inclusive depois de resposta perdida.
        if (resultado is! Map ||
            resultado['protocolo'] != 1 ||
            resultado['id_operacao'] != id ||
            resultado['sucesso'] != true) {
          throw StateError('O servidor nao confirmou o pedido com seguranca.');
        }
        if (op['acao'] == 'abertura' &&
            ((int.tryParse('${resultado['id_comanda_pedido']}') ?? 0) <= 0 ||
                '${resultado['versao_atendimento'] ?? ''}'.isEmpty)) {
          throw StateError(
              'O servidor nao confirmou a identidade da abertura.');
        }
        if (op['acao'] == 'venda' &&
            ((int.tryParse('${resultado['idVenda']}') ?? 0) <= 0 ||
                '${resultado['numeroPedido'] ?? ''}'.isEmpty)) {
          throw StateError('O servidor nao confirmou a identidade da venda.');
        }
        await banco.atualizarOperacao(id, {
          'estado': 'registrado',
          'resposta': jsonEncode(resultado),
          'erro': null,
          'proxima': 0
        });
      }
      if (alvo != escopo || usuario.usuario == null) return;
      final atual =
          (await banco.db.query('operacoes', where: 'id = ?', whereArgs: [id]))
              .single;
      final recibo = AtendimentosLocais.recibo(atual);
      final mensagens =
          List<String>.from(jsonDecode(op['impressoes'] as String))
              .map((mensagem) {
        final dados = jsonDecode(mensagem) as Map<String, dynamic>;
        if (recibo['numeroPedido'] != null) {
          dados['numeroPedido'] = recibo['numeroPedido'];
        }
        if (op['acao'] == 'venda') {
          dados['comanda'] = 'Balcão ${recibo['idVenda']}';
        }
        return jsonEncode(dados);
      }).toList();
      // O comprovante so entra na fila depois do commit confirmado no servidor.
      await socket.filaImpressao
          .registrar(mensagens, servidor: op['destino'] as String);
      await banco.atualizarOperacao(id, {'estado': 'concluido', 'erro': null});
      _detalhesAtualizados.remove(atendimento);
      socket.write(jsonEncode({
        'tipo': op['acao'] == 'venda'
            ? 'Balcão'
            : jsonDecode(op['dados'] as String)['tipo'] == 'mesa'
                ? 'Mesa'
                : 'Comanda'
      }));
      await socket.processarImpressoesPendentes();
    }
  }

  Future<void> _atualizarConsultas(
      String alvo, String url, String empresa, String idUsuario) async {
    for (final rota in [
      'mesas/listar.php',
      'comandas/listar.php',
      'categorias/listar.php',
      'config_bigchef/listar.php',
      'comandas/listar_clientes.php',
      'comandas/listar_mesas.php'
    ]) {
      if (alvo != escopo) return;
      final resposta = await api.cliente.get(rota,
          queryParameters: {
            'empresa': empresa,
            if (!['categorias/listar.php', 'config_bigchef/listar.php']
                .contains(rota))
              'pesquisa': ''
          },
          options: _opcoes(url));
      if (resposta.data is! List && resposta.data is! Map) {
        throw StateError('Lista invalida recebida do servidor.');
      }
      await banco.guardarConsulta(
          alvo, CacheConsultas.chave(resposta.requestOptions), resposta.data);
      if (rota == 'mesas/listar.php' || rota == 'comandas/listar.php') {
        final tipo = rota.startsWith('mesas/') ? 'Mesa' : 'Comanda';
        final campo = tipo == 'Mesa' ? 'mesas' : 'comandas';
        for (final grupo in resposta.data as List) {
          for (final recurso in (grupo[campo] as List? ?? [])) {
            final id = recurso['idComandaPedido']?.toString() ?? '';
            if (id.isEmpty || id == '0' || alvo != escopo) continue;
            final ultima = _detalhesAtualizados[id];
            if (ultima != null &&
                DateTime.now().difference(ultima) <
                    const Duration(seconds: 60)) {
              continue;
            }
            for (final mostrar in ['Não', 'Sim']) {
              final detalhe =
                  await api.cliente.get('cardapio/listar_por_id.php',
                      queryParameters: {
                        'id': id,
                        'codigoQrcode': 'null',
                        'empresa': empresa,
                        'id_usuario': idUsuario,
                        'tipo': tipo,
                        'mostrar_itens': mostrar
                      },
                      options: _opcoes(url));
              if (detalhe.data is Map && detalhe.data['id']?.toString() == id) {
                await banco.guardarConsulta(alvo,
                    CacheConsultas.chave(detalhe.requestOptions), detalhe.data);
              }
            }
            _detalhesAtualizados[id] = DateTime.now();
          }
        }
      }
    }
  }

  Future<void> _carregarCatalogo(
      String alvo, String url, String empresa, String idUsuario) async {
    final produtos = <Map<String, dynamic>>[];
    for (var pagina = 1;; pagina++) {
      if (alvo != escopo || _descartado) return;
      final resposta = await api.cliente.get(
          'produtos/listar_por_categoria.php',
          queryParameters: {
            'categoria': '0',
            'empresa': empresa,
            'id_usuario': idUsuario,
            'pagina': pagina
          },
          options: _opcoes(url));
      if (resposta.data is! List) throw StateError('Cardapio invalido.');
      final itens = List<Map<String, dynamic>>.from(resposta.data as List);
      produtos.addAll(itens);
      if (itens.length < 15) break;
    }
    final detalhes = <String, dynamic>{};
    for (final produto in produtos) {
      final tamanhos = <String>{
        '0',
        ...(produto['tamanhosPizza'] as List? ?? [])
            .map((t) => t['id'].toString())
      };
      for (final tamanho in tamanhos) {
        if (alvo != escopo || _descartado) return;
        final resposta = await api.cliente.get('produtos/listar_por_id.php',
            queryParameters: {
              'id': produto['id'],
              'empresa': empresa,
              'id_usuario': idUsuario,
              'id_tamanhos_pizza': tamanho
            },
            options: _opcoes(url));
        if (resposta.data is! Map || resposta.data['id'] != produto['id']) {
          throw StateError(
              'Nao foi possivel preparar todas as opcoes do cardapio.');
        }
        detalhes['${produto['id']}:$tamanho'] = resposta.data;
        if (tamanho == '0') detalhes['${produto['id']}:'] = resposta.data;
      }
    }
    if (alvo != escopo || _descartado) return;
    final categorias = await api.cliente.get('categorias/listar.php',
        queryParameters: {'empresa': empresa}, options: _opcoes(url));
    if (alvo != escopo || _descartado) return;
    final especiais = <String, dynamic>{
      for (final categoria in categorias.data as List)
        if (categoria['produtosPromocao'] is List)
          categoria['id'].toString(): categoria['produtosPromocao'],
    };
    final catalogo = jsonEncode({
      'produtos': produtos,
      'detalhes': detalhes,
      'categorias': categorias.data,
      'categoriasEspeciais': especiais
    });
    final mudou = await banco.ler('catalogo:$alvo') != catalogo;
    await banco.db.transaction((tx) async {
      await BancoLocal.gravarDocumento(tx, 'catalogo:$alvo', catalogo);
      await tx.delete('consultas',
          where: 'escopo = ? AND chave LIKE ?',
          whereArgs: [alvo, '["produtos/%']);
    });
    _ultimoCatalogo = DateTime.now();
    catalogoPronto = true;
    if (mudou) revisaoCatalogo.value++;
    aoAtualizarTelas?.call();
  }

  Future<void> tentarNovamente() async {
    for (final op in await banco.operacoes(escopo)) {
      if (op['estado'] != 'conflito') {
        await banco.atualizarOperacao(op['id'] as String, {'proxima': 0});
      }
    }
    await sincronizar();
    await enviarPendentes();
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _timer?.cancel();
    usuario.removeListener(_sessaoMudou);
    socket.removeListener(_socketMudou);
    socket.aoAtualizarDados = null;
    api.cache?.aoAtualizar = null;
    if (identical(instancia, this)) instancia = null;
    revisaoCatalogo.dispose();
    super.dispose();
  }
}
