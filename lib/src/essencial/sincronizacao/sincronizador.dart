import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/observacao_produto.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:app/src/modulos/delivery/servicos/preparacao_delivery_offline.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'banco_local.dart';
import 'atendimentos_locais.dart';
import 'cache_consultas.dart';
import 'execucao_segundo_plano.dart';
import 'seguranca_pendencias.dart';

class Sincronizador extends ChangeNotifier {
  static Sincronizador? instancia;
  final DioCliente api;
  final UsuarioProvedor usuario;
  final Server socket;
  final BancoLocal banco;
  late final _preparacaoDelivery = PreparacaoDeliveryOffline(api);
  Timer? _timer;
  Future<void>? _emAndamento;
  Future<void>? _enviando;
  Future<void> _filaOperacoes = Future.value();
  Future<void>? _retentativaManual;
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
  int _rascunhosParaConferir = 0;
  void Function()? aoAtualizarTelas;

  Sincronizador(this.api, this.usuario, this.socket, {BancoLocal? banco})
      : banco = banco ?? BancoLocal.instancia!;

  bool get sincronizando =>
      _emAndamento != null || _enviando != null || _retentativaManual != null;
  int get conflitos =>
      _rascunhosParaConferir +
      pendencias.where((e) => e['estado'] == 'conflito').length;
  int get impressoesPendentes => socket.filaImpressao.itens
      .where((p) =>
          p.servidor == destino &&
          p.dados['idEmpresa']?.toString() == usuario.usuario?.empresa)
      .length;

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
    _rascunhosParaConferir = 0;
    online = false;
    erro = null;
    catalogoPronto = false;
    ultimaAtualizacao = null;
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
    if (_emAndamento == null) {
      unawaited(sincronizar());
    } else if (escopo.isNotEmpty) {
      // Uma preparacao extensa de catalogo nao pode atrasar pedidos prontos
      // quando a rede volta. A fila de envio tem exclusao mutua propria.
      unawaited(enviarPendentes());
    }
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
    ultimaAtualizacao = null;
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
    ultimaAtualizacao = DateTime.tryParse(
        await banco.ler('ultima-sincronizacao:$escopo') ?? '');
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
    final produtosParaEnvio =
        normalizarProdutosParaEnvio(itens.map((e) => e.toMap()).toList());
    await ArmazenamentoCarrinhos.instancia.finalizarDuravel(
      escopo: alvo,
      contexto: contexto,
      itens: itens,
      dados: {
        'produtos': produtosParaEnvio,
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

  Future<void> guardarEdicaoProdutoFinalizado({
    required String tipo,
    required String idAtendimento,
    required String versaoAtendimento,
    required String idItemVenda,
    required Modelowordprodutos produto,
    required String idMesa,
    required String idComanda,
    required String idCliente,
    required List<String> impressoes,
  }) async {
    await configurar();
    final conta = usuario.usuario;
    if (escopo.isEmpty ||
        conta == null ||
        !['mesa', 'comanda'].contains(tipo) ||
        conta.empresa == null ||
        conta.id == null) {
      throw StateError('O atendimento nao pertence a esta conexao.');
    }
    var idAtendimentoEnvio = idAtendimento;
    if (AtendimentosLocais.local(idAtendimento)) {
      final abertura =
          await AtendimentosLocais(banco, escopo).abertura(idAtendimento);
      final recibo =
          abertura == null ? null : AtendimentosLocais.recibo(abertura);
      final real = recibo?['id_comanda_pedido']?.toString() ?? '';
      if (real.isEmpty ||
          ['conflito', 'arquivado'].contains(abertura!['estado'])) {
        throw StateError('Aguarde a confirmacao do servidor antes de editar.');
      }
      idAtendimentoEnvio = real;
    }
    if (idAtendimentoEnvio.isEmpty || idItemVenda.isEmpty) {
      throw StateError('Aguarde a confirmacao do servidor antes de editar.');
    }
    final alvo = escopo;
    final destinoOriginal = destino;
    final estadoSalvo = await banco.ler('estado:$alvo');
    final atendimento = estadoSalvo == null
        ? null
        : (jsonDecode(estadoSalvo)['atendimentos']
            as Map?)?[idAtendimentoEnvio];
    final versao = versaoAtendimento.isNotEmpty
        ? versaoAtendimento
        : ((await banco.ler('versao:$alvo:$idAtendimentoEnvio')) ??
            atendimento?['versao']?.toString() ??
            '');
    if (versao.isEmpty) {
      throw StateError('Aguarde a primeira sincronizacao deste atendimento.');
    }
    if (alvo != escopo || !identical(conta, usuario.usuario)) {
      throw StateError('A conta mudou. Abra a edicao novamente.');
    }
    final payload = {
      'produto': normalizarProdutoParaEnvio(produto.toMap()),
      'id_itens_venda': idItemVenda,
      'id_comanda_pedido': idAtendimentoEnvio,
      'versao_atendimento': versao,
      'id_comanda': idComanda.isEmpty ? '0' : idComanda,
      'id_mesa': idMesa.isEmpty ? '0' : idMesa,
      'tipo': tipo,
      'id_cliente': idCliente.isEmpty ? '0' : idCliente,
      'empresa': conta.empresa,
      'id_usuario': conta.id,
    };
    await banco.db.insert('operacoes', {
      'id': BancoLocal.novoId(),
      'escopo': alvo,
      'atendimento': idAtendimentoEnvio,
      'acao': 'editar_item',
      'estado': 'pendente',
      'dados': jsonEncode(payload),
      'impressoes': jsonEncode(impressoes),
      'destino': destinoOriginal,
      'criado': DateTime.now().millisecondsSinceEpoch,
    });
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
    final payload = {
      ...dados,
      'produtos': normalizarProdutosParaEnvio(dados['produtos']),
      'caixa_id': estado['caixa_id']
    };
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
    if (_emAndamento != null) return _emAndamento!;
    final execucao = _emAndamento = _sincronizar().whenComplete(() {
      _emAndamento = null;
      _notificar();
      if (_solicitada && !_descartado) solicitar();
    });
    _notificar();
    return execucao;
  }

  Options _opcoes(String url) => Options(
        extra: {'semCache': true, 'servidorFixo': url},
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
      );

  // O envio automatico e as acoes de recuperacao compartilham a mesma fila.
  // Assim nao arquivamos/devolvemos um pedido enquanto o HTTP esta em voo.
  Future<T> _operacaoExclusiva<T>(Future<T> Function() acao) {
    final resultado = _filaOperacoes.then((_) => acao());
    _filaOperacoes =
        resultado.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return resultado;
  }

  Future<void> enviarPendentes() => _enviando ??= () async {
        try {
          await configurar();
          if (escopo.isNotEmpty) {
            final alvo = escopo;
            final url = servidor;
            await _operacaoExclusiva(() => ExecucaoSegundoPlano.executar(
                () => _enviarPendentes(alvo, url)));
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
      // A recuperacao da cozinha nao depende das consultas do cardapio.
      unawaited(socket.processarImpressoesPendentes());
      alvo = escopo;
      final url = servidor;
      final empresa = usuario.usuario!.empresa;
      final idUsuario = usuario.usuario!.id;
      final chaveCarrinhos = banco.chaveCarrinhos;
      final identidades = await _identidadesRascunhos(alvo, empresa!);
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
      if (estado.data['sucesso'] == true &&
          estado.data['atendimentos'] is Map) {
        await ArmazenamentoCarrinhos.instancia.conferirRascunhosNoServidor(
            chaveDocumento: chaveCarrinhos,
            empresa: empresa,
            identidadesConsultadas: identidades,
            atendimentos: estado.data['atendimentos'] as Map);
      }
      if (estado.data['offline_delivery'] == 1) {
        unawaited(_preparacaoDelivery.preparar(
            escopo: alvo,
            servidor: url,
            empresa: empresa,
            usuario: idUsuario!));
      }
      await enviarPendentes();
      if (alvo != escopo || usuario.usuario == null) return;
      // Prepara conjuntos independentes em paralelo. Uma falha em uma lista
      // financeira nao impede que o cardapio seja salvo para uso offline.
      await Future.wait<void>([
        _atualizarConsultas(alvo, url, empresa, idUsuario!),
        if (_ultimoCatalogo == null ||
            DateTime.now().difference(_ultimoCatalogo!) >
                const Duration(minutes: 2))
          _carregarCatalogo(alvo, url, empresa, idUsuario),
        for (final rota in [
          'listar_banco_pix',
          'listar_datas_vendas',
          'listar_bancos'
        ])
          () async {
            if (alvo != escopo) return;
            final resposta = await api.cliente.get('tela_nfe_saida/$rota.php',
                queryParameters: rota == 'listar_bancos'
                    ? {'id_empresa': empresa, 'id_usuario': idUsuario}
                    : {'empresa': empresa},
                options: _opcoes(url));
            await banco.guardarConsulta(alvo!,
                CacheConsultas.chave(resposta.requestOptions), resposta.data);
          }(),
      ]);
      if (alvo != escopo) return;
      ultimaAtualizacao = DateTime.now();
      await banco.gravar(
          'ultima-sincronizacao:$alvo', ultimaAtualizacao!.toIso8601String());
      aoAtualizarTelas?.call();
    } on DioException catch (e) {
      if (alvo != escopo) return;
      if (CacheConsultas.falhaDeConexao(e)) {
        online = false;
      } else {
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
      final rascunhos = await rascunhosBloqueados();
      if (alvo == escopo && !_descartado) {
        pendencias = itens;
        _rascunhosParaConferir = rascunhos.length;
      }
    } catch (_) {
      erro =
          'Nao foi possivel acessar os pedidos salvos. Verifique o armazenamento do aparelho.';
    }
  }

  Future<Map<String, String>> _identidadesRascunhos(
      String alvo, String empresa) async {
    final carrinhos =
        jsonDecode(await banco.ler(banco.chaveCarrinhos) ?? '{}') as Map;
    final identidades = <String, String>{};
    for (final carrinho in carrinhos.values.whereType<Map>()) {
      if (carrinho['empresa'] != empresa ||
          !['mesa', 'comanda'].contains(carrinho['tipo'])) {
        continue;
      }
      final id = '${carrinho['idAtendimento'] ?? ''}';
      if (AtendimentosLocais.local(id)) {
        final abertura = await AtendimentosLocais(banco, alvo).abertura(id);
        final real = abertura == null
            ? null
            : AtendimentosLocais.recibo(abertura)['id_comanda_pedido'];
        if (real != null) identidades[id] = '$real';
      } else if ((int.tryParse(id) ?? 0) > 0) {
        identidades[id] = id;
      }
    }
    return identidades;
  }

  Future<void> arquivarConflito(String id) async {
    await configurar();
    final alvo = escopo;
    await _operacaoExclusiva(() => banco.db.transaction((tx) async {
          if (alvo.isEmpty || alvo != escopo) return;
          final operacao = (await tx.query('operacoes',
                  where: 'id = ? AND escopo = ? AND estado = ?',
                  whereArgs: [id, alvo, 'conflito']))
              .firstOrNull;
          if (operacao == null) return;
          await tx.update('operacoes', {'estado': 'arquivado'},
              where: 'id = ?', whereArgs: [id]);
          if (operacao['acao'] == 'abertura' ||
              SegurancaPendencias.conflitoDefinitivo(operacao)) {
            await tx.update(
                'operacoes',
                {
                  'estado': 'conflito',
                  'codigo_erro': 'origem_nao_confirmada',
                  'erro':
                      'O atendimento original foi encerrado ou descartado. Confira os produtos antes de excluir a sincronizacao.'
                },
                where: "escopo = ? AND atendimento = ? AND estado = 'pendente'",
                whereArgs: [alvo, operacao['atendimento']]);
          }
        }));
    await _recarregarPendencias();
    _notificar();
  }

  Future<void> reenviarParaServidor(String id) async {
    if (_descartado) return;
    await configurar();
    if (escopo.isEmpty || _descartado) return;
    final alvo = escopo;
    await _operacaoExclusiva(() async {
      if (alvo != escopo || _descartado) return;
      final operacao = (await banco.db.query(
        'operacoes',
        where:
            "id = ? AND escopo = ? AND estado NOT IN ('concluido', 'arquivado')",
        whereArgs: [id, alvo],
        limit: 1,
      ))
          .firstOrNull;
      if (operacao == null) return;
      if (SegurancaPendencias.conflitoDefinitivo(operacao)) {
        throw StateError('Este atendimento nao pode mais receber este pedido.');
      }
      final recusada = operacao['estado'] == 'conflito';
      final atualizadas = await banco.db.update(
        'operacoes',
        {
          if (recusada) ...{
            'estado': 'pendente',
            'dados': jsonEncode(
                _normalizarDadosOperacao(AtendimentosLocais.dados(operacao))),
            'tentativas': 0,
          },
          'erro': null,
          'codigo_erro': null,
          'proxima': 0,
        },
        where:
            "id = ? AND escopo = ? AND estado NOT IN ('concluido', 'arquivado')",
        whereArgs: [id, alvo],
      );
      if (atualizadas == 0) return;
    });
    await _recarregarPendencias();
    _notificar();
    await enviarPendentes();
  }

  Future<void> voltarPedidoParaCarrinho(String id) async {
    if (_descartado) return;
    await configurar();
    if (escopo.isEmpty || _descartado) return;
    final alvo = escopo;
    final chaveDocumento = banco.chaveCarrinhos;
    final empresa = usuario.usuario!.empresa!;
    await _operacaoExclusiva(() async {
      if (alvo != escopo || _descartado) return;
      final operacao = (await banco.db.query(
        'operacoes',
        where:
            "id = ? AND escopo = ? AND estado NOT IN ('concluido', 'arquivado')",
        whereArgs: [id, alvo],
        limit: 1,
      ))
          .firstOrNull;
      if (operacao == null) {
        throw StateError('Pedido nao encontrado na fila do aparelho.');
      }
      if (!SegurancaPendencias.podeRecuperar(operacao)) {
        throw StateError(
            'Este envio pode ja ter sido recebido, ou o atendimento foi encerrado. Confira a sincronizacao.');
      }
      final dados = AtendimentosLocais.dados(operacao);
      final produtos = normalizarProdutosParaEnvio(dados['produtos'])
          .map(Modelowordprodutos.fromMap)
          .map((produto) => produto..conferidoNoCarrinho = false)
          .toList();
      if (produtos.isEmpty) {
        throw StateError('Nao foi possivel recuperar os itens desse pedido.');
      }
      final acao = operacao['acao']?.toString() ?? '';
      final tipo =
          (dados['tipo'] ?? (acao == 'venda' ? 'balcao' : '')).toString();
      if (!['mesa', 'comanda', 'balcao'].contains(tipo)) {
        throw StateError('Esse tipo de pedido nao pode voltar ao carrinho.');
      }
      final idAtendimento = tipo == 'balcao'
          ? '0'
          : (dados['id_comanda_pedido'] ?? operacao['atendimento'] ?? '')
              .toString();
      final idRecurso = tipo == 'mesa'
          ? (dados['id_mesa'] ?? '').toString()
          : tipo == 'comanda'
              ? (dados['id_comanda'] ?? '').toString()
              : '';
      final contexto = ContextoCarrinho(
        empresa: empresa,
        tipo: tipo,
        idAtendimento: idAtendimento,
        idRecurso: idRecurso,
      );
      await ArmazenamentoCarrinhos.instancia.recuperarOperacao(
        id: id,
        escopo: alvo,
        chaveDocumento: chaveDocumento,
        contexto: contexto,
        produtos: produtos,
      );
    });
    await _recarregarPendencias();
    aoAtualizarTelas?.call();
    _notificar();
  }

  Future<void> arquivarRascunho(Map<String, dynamic> rascunho) async {
    await configurar();
    if (escopo.isEmpty || rascunho['empresa'] != usuario.usuario?.empresa) {
      return;
    }
    final alvo = escopo;
    final chaveDocumento = banco.chaveCarrinhos;
    await _operacaoExclusiva(() async {
      if (alvo != escopo) return;
      await ArmazenamentoCarrinhos.instancia.arquivarRascunhoBloqueado(
        contexto: ContextoCarrinho.fromMap(rascunho),
        chaveDocumento: chaveDocumento,
      );
    });
    await _recarregarPendencias();
    aoAtualizarTelas?.call();
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
            'codigo_erro': 'origem_nao_confirmada',
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
            'codigo_erro': 'origem_nao_confirmada',
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
        var dados = jsonDecode(op['dados'] as String) as Map<String, dynamic>;
        if (op['tentativas'] == 0) {
          final normalizados = _normalizarDadosOperacao(dados);
          if (jsonEncode(normalizados) != jsonEncode(dados)) {
            await banco
                .atualizarOperacao(id, {'dados': jsonEncode(normalizados)});
            dados = normalizados;
          }
        }
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
                'impressoes': jsonDecode(op['impressoes'] as String),
                'dados': dados
              }),
              options: _opcoes(url));
        } on DioException catch (e) {
          final mensagem = e.response?.data;
          if ((e.response?.statusCode == 409 ||
                  e.response?.statusCode == 422) &&
              mensagem is Map &&
              mensagem['protocolo'] == 1 &&
              mensagem['sucesso'] == false) {
            await banco.atualizarOperacao(id, {
              'estado': 'conflito',
              'codigo_erro': mensagem['codigo']?.toString(),
              'erro': mensagem['mensagem']?.toString() ??
                  'O atendimento mudou. Confira este pedido com o responsavel.'
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
        if (op['acao'] == 'delivery' &&
            ((int.tryParse('${resultado['idDelivery']}') ?? 0) <= 0 ||
                '${resultado['numeroPedido'] ?? ''}'.isEmpty)) {
          throw StateError(
              'O servidor nao confirmou a identidade do Delivery.');
        }
        if (op['acao'] == 'editar_item' &&
            (int.tryParse('${resultado['id_itens_venda']}') ?? 0) <= 0) {
          throw StateError('O servidor nao confirmou a edicao do produto.');
        }
        await banco.atualizarOperacao(id, {
          'estado': 'registrado',
          'resposta': jsonEncode(resultado),
          'erro': null,
          'codigo_erro': null,
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
              .where((mensagem) =>
                  recibo['impressao_persistida'] != true ||
                  jsonDecode(mensagem)['tipoImpressao']?.toString() != '1')
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
      // A API atual assume o preparo na mesma transacao. Nao enviar outra via
      // ao central do socket: ele pode ser diferente daquele que reservou a
      // outbox. APIs antigas e comprovantes de outros tipos mantem a fila local.
      if (mensagens.isNotEmpty) {
        await socket.filaImpressao
            .registrar(mensagens, servidor: op['destino'] as String);
      }
      await banco.atualizarOperacao(id, {'estado': 'concluido', 'erro': null});
      _detalhesAtualizados.remove(atendimento);
      socket.write(jsonEncode({
        'tipo': op['acao'] == 'delivery'
            ? 'Delivery'
            : op['acao'] == 'venda'
                ? 'Balcão'
                : jsonDecode(op['dados'] as String)['tipo'] == 'mesa'
                    ? 'Mesa'
                    : 'Comanda'
      }));
      if (recibo['impressao_persistida'] == true) {
        socket.write(jsonEncode({'tipo': 'PreparoPendente'}));
      }
      await socket.processarImpressoesPendentes();
    }
  }

  Map<String, dynamic> _normalizarDadosOperacao(Map<String, dynamic> dados) {
    final copia = Map<String, dynamic>.from(dados);
    if (copia.containsKey('produtos')) {
      copia['produtos'] = normalizarProdutosParaEnvio(copia['produtos']);
    }
    if (copia.containsKey('produto')) {
      copia['produto'] = normalizarProdutoParaEnvio(copia['produto']);
    }
    return copia;
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
    if (alvo != escopo || _descartado) return;
    _ultimoCatalogo = DateTime.now();
    catalogoPronto = true;
    if (mudou) revisaoCatalogo.value++;
    aoAtualizarTelas?.call();
  }

  Future<void> tentarNovamente() {
    if (_descartado) return Future.value();
    if (_retentativaManual != null) return _retentativaManual!;
    final tentativa = _retentativaManual = _tentarNovamente().whenComplete(() {
      _retentativaManual = null;
      _notificar();
    });
    _notificar();
    return tentativa;
  }

  Future<void> _tentarNovamente() async {
    await configurar();
    if (escopo.isEmpty || _descartado) return;
    final impressao =
        socket.processarImpressoesPendentes(reconectarAgora: true);
    try {
      for (final op in await banco.operacoes(escopo)) {
        if (op['estado'] != 'conflito') {
          await banco.atualizarOperacao(op['id'] as String, {'proxima': 0});
        }
      }
      await sincronizar();
      await enviarPendentes();
    } finally {
      await impressao;
    }
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
