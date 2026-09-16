# Delivery no aplicativo

Implementacao exclusiva do `sistemadevenda`. O projeto `sistemarestaurante` e o PHP
existente foram usados somente como referencia, sem alteracoes.

## Fluxo

- Inicio > Delivery: etapas cadastradas em `opcoes_carrossel`, contadores,
  pesquisa por pedido/cliente/telefone, periodo comercial e tipo de entrega.
- Celular: carrossel com uma etapa por vez. Tablet: duas ou tres colunas conforme
  a largura. Listas preservadas durante atualizacoes e em falhas de conexao.
- Novo pedido: entrega, retirada ou consumo local; selecao/cadastro de cliente,
  selecao/cadastro de endereco, taxa configurada e observacao.
- Cardapio e carrinho existentes, com contexto separado por pedido Delivery.
  Finalizar adiciona os produtos ao pedido e retorna ao carrossel. Nao recebe
  pagamento nem muda a etapa automaticamente.
- Avancar respeita a ordem configurada, recebimento antecipado/no final,
  selecao de entregador e tipo de impressao da etapa de destino.
- Detalhes: produtos e complementos, endereco, pagamentos, contato telefonico,
  novos produtos, recebimento parcial e reimpressao.
- Pagamento registra recebimento, com troco apenas em dinheiro. Nao realiza
  cobranca de cartao ou Pix no banco/terminal. Venda gerada ou cancelada bloqueia
  novos lancamentos. O servidor deve continuar validando autorizacoes.

## Integracao

`ServicoDelivery` usa `/sistema/apis_restaurantes/api_desktop/1.0.01/` no mesmo
servidor configurado para o aplicativo, com empresa e usuario da sessao atual.
Essa API precisa estar publicada e acessivel tambem quando a conexao for online.
Consultas operacionais nao usam cache offline e operacoes exigem conexao.

Endpoints principais: `delivery/listar_opcoes.php`, `listar_opcoes_por_id.php`,
`inserir.php`, `inserir_produtos.php`, `mudar_status_delivery.php`,
`pagar_pedido.php`, `finalizar_pedido_delivery.php` e `cardapio/listar_por_id.php`.
O cadastro aplica a taxa por `cardapio/editar_tipo_de_entrega_cliente.php` antes
de abrir o cardapio. A configuracao considera taxa fixa/bairro e diferenca de
horario calculada pelo servidor.

Impressao usa a fila persistente do aplicativo (`Server.enviarImpressoes`),
com os destinos dos produtos e o endereco selecionado. Reimpressao fica no menu
dos detalhes. Mudanca de etapa pode acionar mensagens automaticas ja configuradas
no servidor, como acontece no desktop.

As APIs antigas nao oferecem chave de idempotencia para cadastro, insercao de
produtos ou pagamento. Nao ha repeticao automatica de POST. Em resposta incerta,
conferir o pedido/recebimentos antes de repetir. Trocas de etapa revalidam o pedido
antes e depois da alteracao, mas nao substituem controle transacional no servidor.

## Escopo

O fluxo operacional mobile nao inclui os paineis administrativos do desktop:
configuracao de etapas, emissao fiscal, mensagens manuais em massa, clonagem,
cancelamento integral e gerenciamento de pedidos online em espera. Esses recursos
continuam disponiveis no desktop. Os botoes de voz permanecem inalterados.

## Validacao

`flutter analyze` e `flutter test`. Os testes em `test/modulos/delivery` verificam
contratos sem gravar no banco real, saldo/troco, bloqueios, corrida de consultas,
mudanca de etapa e layouts de celular/tablet. Capturas opcionais usam os mesmos
parametros `CAPTURAR_TELAS` e `FONTE_TESTE` dos demais testes visuais.

Homologar no estabelecimento: cliente/endereco reais de teste, novo pedido,
preparo, pagamento parcial/completo, entregador, conclusao e impressao fisica.
Os testes automatizados nao efetuam vendas nem imprimem na cozinha real.
