import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:app/src/modulos/mesas/servicos/servico_mesas.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

import 'abertura_falada.dart';
import 'dialogo_pedido_voz.dart';
import 'gravador_voz.dart';
import 'pedido_falado.dart';
import 'servico_abertura_voz.dart';
import 'servico_pedido_voz.dart';

class BotaoAberturaVoz extends StatefulWidget {
  final TipoAberturaVoz tipo;
  final Future<void> Function() onAberto;
  const BotaoAberturaVoz(
      {super.key, required this.tipo, required this.onAberto});

  @override
  State<BotaoAberturaVoz> createState() => _BotaoAberturaVozState();
}

class _BotaoAberturaVozState extends State<BotaoAberturaVoz>
    with WidgetsBindingObserver {
  bool _ocupado = false;
  bool _resolvendo = false;
  bool _interrompida = false;
  ServicoPedidoVoz? _voz;
  DioCliente? _consulta;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_resolvendo && state != AppLifecycleState.resumed) _interrompida = true;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _voz?.dispose();
    _voz = null;
    _consulta?.cliente.close(force: true);
    _consulta = null;
    super.dispose();
  }

  Future<void> _abrir() async {
    if (_ocupado) return;
    setState(() => _ocupado = true);
    _interrompida = false;
    String? idSalvo;
    try {
      if (kIsWeb ||
          ![TargetPlatform.android, TargetPlatform.iOS]
              .contains(defaultTargetPlatform)) {
        throw const FalhaPedidoVoz(
            'A voz esta disponivel no aplicativo Android e iPhone.');
      }
      final usuario = Modular.get<UsuarioProvedor>();
      final identidade = usuario.usuario;
      final sync = Sincronizador.instancia;
      if (identidade == null || sync == null) {
        throw const FalhaPedidoVoz(
            'Entre na sua conta e aguarde a sincronizacao.');
      }
      final servidor = (await Apis().getConexao()).servidor;
      if (!mounted) return;
      Future<void> validar() async {
        final atual = (await Apis().getConexao()).servidor;
        if (!mounted ||
            _interrompida ||
            ModalRoute.of(context)?.isCurrent != true ||
            !identical(identidade, usuario.usuario) ||
            !identical(sync, Sincronizador.instancia) ||
            servidor != atual) {
          throw const FalhaPedidoVoz(
              'A abertura foi interrompida. Confira o atendimento antes de tentar novamente.');
        }
      }

      final voz = _voz = ServicoPedidoVoz(servidor: servidor, usuario: usuario);
      final gravador = GravadorVoz();
      final comando = await showDialog<AberturaFalada>(
          context: context,
          barrierDismissible: false,
          builder: (_) => DialogoPedidoVoz(
              atendimento:
                  widget.tipo == TipoAberturaVoz.mesa ? 'Mesas' : 'Comandas',
              abertura: widget.tipo,
              servico: voz,
              gravador: gravador,
              descartarServicoAoFechar: false));
      if (comando == null || !mounted) return;
      _resolvendo = true;
      await validar();
      final consulta = _consulta = DioCliente(servidor: servidor)
        ..cliente.options.extra['semCache'] = true;
      idSalvo = await ServicoAberturaVoz(
              comandas: ServicoComandas(consulta, usuario),
              mesas: ServicoMesas(consulta, usuario),
              sincronizador: sync,
              voz: voz,
              validarSessao: validar)
          .abrir(comando);
      await validar();
      if (!mounted) return;
      DefaultTabController.maybeOf(context)?.animateTo(0);
      await widget.onAberto();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              '${widget.tipo == TipoAberturaVoz.mesa ? 'Mesa' : 'Comanda'} ${comando.numero}: abertura salva. Confira a sincronizacao.'),
          showCloseIcon: true));
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(idSalvo != null
                ? 'A abertura ja foi salva. Atualize a lista e confira a sincronizacao.'
                : erro is FalhaPedidoVoz
                    ? erro.mensagem
                    : erro is StateError
                        ? erro.message.toString()
                        : 'Nao foi possivel concluir. Confira a sincronizacao antes de tentar novamente.'),
            showCloseIcon: true));
      }
    } finally {
      _voz?.dispose();
      _voz = null;
      _consulta?.cliente.close(force: true);
      _consulta = null;
      _resolvendo = false;
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
      dimension: 48,
      child: IconButton.filledTonal(
          key: ValueKey('abrir_${widget.tipo.name}_por_voz'),
          tooltip: 'Abrir ${widget.tipo.name} por voz',
          onPressed: _ocupado ? null : _abrir,
          style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
          icon: _ocupado
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.mic_rounded, size: 22)));
}
