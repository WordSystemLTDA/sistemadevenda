# Delivery no aplicativo

Implementacao mobile no `sistemadevenda`, integrada ao contrato da API39.
O projeto `sistemarestaurante` fornece os mesmos cadastros e regras de entrega.

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

`ServicoDelivery` usa a API de venda configurada no aplicativo, atualmente
`/sistema/apis_restaurantes/api_restaurantes_venda/api39/`, com empresa e usuario
da sessao. Em Online usa a hospedagem; em Local usa o servidor configurado.
As consultas de enderecos podem usar o cache offline e sao renovadas pela API.

Em 08/10/2026, `enderecos_clientes/listar_por_cliente.php` Online retornava
HTTP 500 porque `api_desktop/1.0.01/funcoes/taxa_entrega.php` nao estava publicado.
A API39 agora acompanha `funcoes/taxa_entrega.php`, reutilizando o desktop
quando presente e oferecendo o mesmo calculo quando ausente. A listagem
mantem os enderecos da mesma empresa/cliente, prioriza o marcado como padrao
e conserva dados de bairro, cidade e taxa. A tela seleciona esse endereco;
falha na consulta passa a aparecer junto da secao de enderecos, com tentativa
pelo botao Atualizar, em vez de informar que nao existe endereco cadastrado.

Publicar o pacote `build/correcoes/api39_endereco_padrao_delivery_20261008.zip`
na hospedagem, preservando a estrutura de pastas, e atualizar o aplicativo.
O pacote inclui o helper e os recebimentos que calculam taxa na API39.
Nao substitui `conexao.php`, nao altera cadastros nem cria estrutura de banco.

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

Na correcao de enderecos de 08/10/2026 passaram 64 testes Flutter de Delivery,
retomada offline e cadastro de clientes. O teste PHP de publicacao executa a
listagem sem helper desktop e confere endereco padrao/alternativo, pesquisa,
isolamento por cliente/empresa e calculos de taxa identicos ao modo Local.
Analise Dart e lint dos seis PHP aprovados; suites PHP de catalogo e
sincronizacao em publicacao isolada tambem aprovadas.

Homologar no estabelecimento: cliente/endereco reais de teste, novo pedido,
preparo, pagamento parcial/completo, entregador, conclusao e impressao fisica.
Os testes automatizados nao efetuam vendas nem imprimem na cozinha real.

## Envio imediato ao finalizar (09/10/2026)

O novo Delivery continua sendo salvo em SQLite antes do envio. A confirmacao
agora inicia a fila imediatamente e aguarda ate 1,2 segundo pelo recibo daquele
pedido ou pelo ACK valido do PC. Com resposta rapida, a tela retorna depois do
recebimento, reduzindo a passagem visivel por **No aparelho**. Expirar essa
espera nao cancela o HTTP, nao descarta o pedido e nao cria uma segunda venda;
a fila existente continua sincronizando. O pedido so participa de Aguardando
depois do recebimento pela API ou pelo PC.

Reconciliacoes de preparos antigos passam depois dos novos envios. A lista
recebida e mostrada antes da consulta auxiliar de configuracao terminar. Uma
notificacao tardia de um ID local ja concluido na API nao o recoloca em
**No aparelho**, preservando o retrato de Preparo quando sua etapa ainda
aguarda reconciliacao. Delivery conserva impressao ao iniciar o preparo;
Mesa e Comanda conservam suas regras existentes.

Validacao: 149 testes de sincronizacao, fila offline, recebimento LAN,
finalizacao, etapas, impressao e telas passaram. As novas verificacoes cobrem
API rapida, HTTP ainda em voo depois da espera curta, reconciliacao lenta,
ACK Wi-Fi sem confirmacao financeira, configuracao lenta e notificacao tardia.
Analise Dart dos arquivos alterados sem apontamentos. Este ajuste altera
somente o aplicativo mobile; requer recompilar/recarregar `sistemadevenda`.

## Carregamento ao retornar da finalizacao (09/10/2026)

Ao retornar ao Delivery ou solicitar uma atualizacao, o indicador de espera
comeca imediatamente, inclusive quando existe uma consulta anterior na fila.
Os pedidos existentes permanecem visiveis. Abas vazias mostram o indicador
**Atualizando pedidos…** ate a resposta atual chegar; so depois uma etapa
realmente vazia apresenta **Nenhum pedido nesta etapa**. Atualizacoes periodicas
em segundo plano conservam o comportamento discreto existente.

O indicador termina assim que a lista e aplicada ou a consulta falha. Uma falha
conserva os pedidos anteriores e mostra o aviso existente para tentar novamente.
O teste visual reproduz uma espera de tres segundos, a retirada da aba local
vazia com preservacao da selecao em Aguardando e uma falha na consulta seguinte.
Outro teste verifica o carregamento antes de uma consulta agrupada iniciar.
