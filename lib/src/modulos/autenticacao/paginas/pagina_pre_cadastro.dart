import 'package:app/src/essencial/constantes/constantes_global.dart';
import 'package:app/src/modulos/autenticacao/modelos/cidade_modelo.dart';
import 'package:app/src/modulos/autenticacao/modelos/pre_cadastro_modelo.dart';
import 'package:app/src/modulos/autenticacao/paginas/pagina_pos_pre_cadastro.dart';
import 'package:app/src/modulos/autenticacao/servicos/servico_autenticacao.dart';
import 'package:app/src/modulos/autenticacao/servicos/servico_cidade.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaPreCadastro extends StatefulWidget {
  const PaginaPreCadastro({super.key});

  @override
  State<PaginaPreCadastro> createState() => _PaginaPreCadastroState();
}

class _PaginaPreCadastroState extends State<PaginaPreCadastro> {
  final _razaoSocialController = TextEditingController();
  final _nomeController = TextEditingController();
  final _tipoPessoaController = TextEditingController(text: 'Física');
  final _docController = TextEditingController();
  final _incEstController = TextEditingController();
  final _emailController = TextEditingController();
  final _celularController = TextEditingController();
  final _cepController = TextEditingController();
  final _enderecoController = TextEditingController();
  final _numeroController = TextEditingController();
  final _bairroController = TextEditingController();
  final _complementoController = TextEditingController();
  final _cidadeController = TextEditingController();
  final _nomeCidadeController = TextEditingController();

  bool eCpf = true;

  @override
  Widget build(BuildContext context) {
    var cidadeServico = context.read<ServicoCidade>();
    var autenticacaoService = context.read<ServicoAutenticacao>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastro'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (_razaoSocialController.text.isEmpty) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Nome completo é Obrigatório!'),
              backgroundColor: Colors.red,
              showCloseIcon: true,
            ));

            return;
          }

          if (_docController.text.isNotEmpty) {
            if (eCpf) {
              if (!UtilBrasilFields.isCPFValido(_docController.text)) {
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('CPF Inválido!'),
                  backgroundColor: Colors.red,
                  showCloseIcon: true,
                ));
                return;
              }
            } else {
              if (!UtilBrasilFields.isCNPJValido(_docController.text)) {
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('CNPJ Inválido!'),
                  backgroundColor: Colors.red,
                  showCloseIcon: true,
                ));
                return;
              }
            }
          }

          autenticacaoService
              .preCadastro(PreCadastroModelo(
            razaoSocial: _razaoSocialController.text,
            nome: _nomeController.text,
            tipoPessoa: _tipoPessoaController.text,
            doc: _docController.text,
            incEst: _incEstController.text,
            email: _emailController.text,
            celular: _celularController.text,
            cep: _cepController.text,
            endereco: _enderecoController.text,
            numero: _numeroController.text,
            bairro: _bairroController.text,
            complemento: _complementoController.text,
            cidade: _cidadeController.text,
          ))
              .then((dados) {
            if (dados[0] == true) {
              // ScaffoldMessenger.of(context).removeCurrentSnackBar();
              // ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              //   content: Text('Cadastro feito com Sucesso. Sua senha para Login é 123'),
              //   backgroundColor: Colors.green,
              //   showCloseIcon: true,
              // ));
              if (context.mounted) {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PaginaPosPreCadastro()));
              }
            } else {
              if (context.mounted) {
                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(dados[1]),
                  backgroundColor: Colors.red,
                  showCloseIcon: true,
                ));
              }
            }
          });
        },
        label: const Row(
          children: [
            Text('Cadastrar'),
            SizedBox(width: 10),
            Icon(Icons.check),
          ],
        ),
      ),
      body: InkWell(
        focusColor: Colors.transparent,
        splashColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(top: 25, left: 10, right: 10, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _razaoSocialController,
                  keyboardType: TextInputType.text,
                  decoration: const InputDecoration(
                    label: Text('Nome Completo'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nomeController,
                        decoration: const InputDecoration(
                          label: Text('Nome'),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    DropdownMenu(
                      width: MediaQuery.of(context).size.width / 2 - 15,
                      label: const Text('Tipo de Pessoa'),
                      initialSelection: _tipoPessoaController.text,
                      onSelected: (value) {
                        _tipoPessoaController.text = value ?? '';
                        if (_tipoPessoaController.text == 'Física') {
                          setState(() => eCpf = true);
                        } else {
                          setState(() => eCpf = false);
                        }
                      },
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: 'Física', label: 'Pessoa Física'),
                        DropdownMenuEntry(value: 'Jurídica', label: 'Pessoa Jurídica'),
                      ],
                    ),
                    // Expanded(
                    //   child: TextField(
                    //     controller: credencialEmpresa,
                    //     keyboardType: TextInputType.number,
                    //     decoration: const InputDecoration(
                    //       suffixIcon: Tooltip(
                    //         triggerMode: TooltipTriggerMode.tap,
                    //         message: 'Esta credencial será fornecida pelo responsável da empresa.',
                    //         child: Icon(Icons.info_outline_rounded),
                    //       ),
                    //       label: Text('Credencial da Empresa'),
                    //       border: OutlineInputBorder(),
                    //     ),
                    //   ),
                    // ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _docController,
                        inputFormatters: eCpf ? ConstantesGlobal.mascaraCPF : ConstantesGlobal.mascaraCNPJ,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          label: eCpf ? const Text('CPF') : const Text('CNPJ'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _incEstController,
                        // inputFormatters: ConstantesGlobal.mascaraRG,
                        // keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          label: eCpf ? const Text('RG') : const Text('Incrição Estadual'),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          label: Text('E-mail'),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _celularController,
                        inputFormatters: ConstantesGlobal.mascaraCelularTelefone,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          label: Text('Celular'),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text('Endereço', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 10),
                TextField(
                  controller: _cepController,
                  inputFormatters: ConstantesGlobal.mascaraCEP,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    label: Text('CEP'),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _numeroController,
                        // keyboardType: TextInputType.number,
                        // inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          label: Text('Número'),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _enderecoController,
                        decoration: const InputDecoration(
                          label: Text('Endereço'),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _complementoController,
                        decoration: const InputDecoration(
                          label: Text('Complemento'),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _bairroController,
                        decoration: const InputDecoration(
                          label: Text('Bairro'),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SearchAnchor(
                  isFullScreen: true,
                  builder: (BuildContext context, SearchController controller) {
                    return TextField(
                      onTap: () {
                        controller.openView();
                      },
                      controller: _nomeCidadeController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        label: Text('Cidade'),
                      ),
                    );
                  },
                  suggestionsBuilder: (BuildContext context, SearchController controller) async {
                    final keyword = controller.value.text;

                    List<CidadeModelo>? cidades = await cidadeServico.listar(keyword);

                    Iterable<Widget> widgets = cidades.map((cidade) {
                      return GestureDetector(
                        onTap: () {
                          controller.closeView('');
                          setState(() {
                            _cidadeController.text = cidade.id;
                            _nomeCidadeController.text = cidade.nome;
                          });
                          FocusScope.of(context).unfocus();
                        },
                        child: Card(
                          elevation: 3.0,
                          child: ListTile(
                            leading: const Icon(Icons.copy_all_outlined),
                            title: Text(cidade.nome),
                            subtitle: Text(
                              cidade.nomeUf,
                              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ),
                      );
                    });

                    return widgets;
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
