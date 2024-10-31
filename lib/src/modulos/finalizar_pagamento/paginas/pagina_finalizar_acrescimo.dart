import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_selecionar_pagamento.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaginaFinalizarAcrescimo extends StatefulWidget {
  final String idVenda;
  final double valor;
  const PaginaFinalizarAcrescimo({super.key, required this.idVenda, required this.valor});

  @override
  State<PaginaFinalizarAcrescimo> createState() => _PaginaFinalizarAcrescimoState();
}

class _PaginaFinalizarAcrescimoState extends State<PaginaFinalizarAcrescimo> {
  final _totalPedidoController = TextEditingController();
  final _acrescimoController = TextEditingController();
  final _descontoController = TextEditingController();
  final _descontoValorController = TextEditingController();

  double _totalReceber = 0;
  double _desconto = 0;

  void calcular() {
    final double acrescimo = _acrescimoController.text.isEmpty ? 0 : double.parse(_acrescimoController.text);
    final double desconto = _descontoController.text.isEmpty ? 0 : double.parse(_descontoController.text);
    final double descontoValor = _descontoValorController.text.isEmpty ? 0 : double.parse(_descontoValorController.text);

    if (desconto == 0) {
      final double valorDescontado = widget.valor - acrescimo + descontoValor;
      setState(() {
        _totalReceber = widget.valor + (widget.valor - valorDescontado);
        _desconto = valorDescontado - widget.valor;
      });
    } else {
      final double valorDescontado = widget.valor * desconto / 100 - acrescimo + descontoValor;
      setState(() {
        _totalReceber = widget.valor - valorDescontado;
        _desconto = valorDescontado;
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _totalPedidoController.text = widget.valor.toStringAsFixed(2);
    _totalReceber = widget.valor;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acréscimo e Decontos'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      resizeToAvoidBottomInset: false,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(5)),
        ),
        backgroundColor: _totalReceber > 0 ? null : const Color.fromARGB(255, 237, 232, 246),
        onPressed: _totalReceber > 0
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaginaSelecionarPagamento(
                      idVenda: widget.idVenda,
                      totalReceber: _totalReceber,
                      desconto: _desconto,
                      acrescimo: _acrescimoController.text,
                      descontoPercentual: _descontoController.text,
                      totalPedido: _totalPedidoController.text,
                    ),
                  ),
                );
              }
            : () {
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Total a Receber não pode ser Negativo', textAlign: TextAlign.center),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ));
              },
        label: SizedBox(
          width: MediaQuery.of(context).size.width - 70,
          child: const Text('Avançar', textAlign: TextAlign.center),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Stack(
          children: [
            Positioned(
              bottom: 120,
              right: 20,
              left: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total a Receber ', style: TextStyle(fontSize: 15)),
                  Text(
                    'R\$ ${_totalReceber.toStringAsFixed(2).replaceAll('.', ',')}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            ListView(
              padding: const EdgeInsets.only(right: 10, left: 10),
              children: [
                const SizedBox(height: 15),
                const Column(
                  children: [
                    // InformacoesApp.getLogoEscuraApp(context, width: 200, height: 100),
                    SizedBox(height: 18),
                    Text('Desconto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    SizedBox(height: 20),
                    Text('Você pode dar desconto em percentual\nou até mesmo em Valor.', style: TextStyle(fontSize: 15), textAlign: TextAlign.center),
                  ],
                ),
                const SizedBox(height: 40),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: TextField(
                          controller: _totalPedidoController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            label: Text('Total do Pedido'),
                            border: OutlineInputBorder(),
                            prefixText: 'R\$  ',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: TextField(
                          controller: _acrescimoController,
                          decoration: InputDecoration(
                            label: const Text('Acréscimo (Valor)'),
                            border: const OutlineInputBorder(),
                            prefixText: 'R\$  ',
                            suffixIcon: IconButton(
                              onPressed: () {
                                _acrescimoController.clear();
                                calcular();
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ),
                          onChanged: (_) => calcular(),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(',', replacementString: '.'),
                            FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d{0,2})')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: TextField(
                          controller: _descontoController,
                          decoration: InputDecoration(
                            label: const Text('Desconto (%)'),
                            border: const OutlineInputBorder(),
                            prefixText: '%  ',
                            suffixIcon: IconButton(
                              onPressed: () {
                                _descontoController.clear();
                                calcular();
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ),
                          onChanged: (_) => calcular(),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(',', replacementString: '.'),
                            FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d{0,2})')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: TextField(
                          controller: _descontoValorController,
                          decoration: InputDecoration(
                            label: const Text('Desconto (Valor)'),
                            border: const OutlineInputBorder(),
                            prefixText: 'R\$  ',
                            suffixIcon: IconButton(
                              onPressed: () {
                                _descontoValorController.clear();
                                calcular();
                              },
                              icon: const Icon(Icons.close),
                            ),
                          ),
                          onChanged: (_) => calcular(),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.deny(',', replacementString: '.'),
                            FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d{0,2})')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 100),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
