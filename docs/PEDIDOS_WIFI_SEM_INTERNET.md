# Pedidos pelo Wi-Fi durante queda de internet

Implementacao de 09/10/2026 para a conexao **Online / API41**. A API continua
responsavel por vendas, pagamentos e numeros oficiais. A rede Wi-Fi leva uma
copia provisoria do pedido ao PC e a fila confiavel de impressao da cozinha.

## Atualizacao necessaria

1. Publicar na raiz da API41 os arquivos do pacote
   `build/delivery_wifi_aguardando_preparo_api41_20261009.zip` do projeto `apis_restaurantes`.
   O pacote contem `sincronizacao/estado.php`, `sincronizacao/operacoes.php`,
   `impressao/reserva_pedido_rede.php`, `impressao/fila_transacional.php`,
   `delivery/confirmar_preparo_rede.php`, `delivery/preparo_rede.php` e
   `delivery/regras_fluxo.php`.
   Nao inclui conexao.php, credenciais nem alteracoes de schema.
2. Recompilar/atualizar **sistemadevenda no celular** e **sistemarestaurante no PC**.
3. Com internet, entrar na mesma empresa nos dois aplicativos, deixar o PC
   como servidor de Atualizacoes Online e aguardar uma sincronizacao. Isso
   salva o cardapio, a capacidade da API e a ultima configuracao de impressao.
4. Manter celular e PC na mesma rede Wi-Fi, o servidor ativo e as impressoras
   configuradas. IP e porta existentes continuam sendo usados pelo canal LAN.

## Comportamento

- Sem internet, pedidos novos de Delivery, Mesa, Comanda e Balcao permanecem
  duraveis no celular. Uma copia imutavel e enviada pelo WebSocket ao PC.
- O PC salva o retrato e todos os destinos de preparo antes de responder.
  No Delivery, a copia aparece no quadro **Aguardando**, junto dos pedidos
  oficiais. O celular tambem coloca o pedido recebido pelo PC em **Aguardando**.
  Rascunhos e pedidos ainda nao recebidos pelo PC conservam **No aparelho**.
  Detalhes de sincronizacao ficam no atalho discreto **Wi-Fi**, sem painel
  expandido nem aviso grande ocupando o cartao.
  O celular informa **Recebido pelo PC via Wi-Fi** depois desse ACK; isso
  significa recebimento duravel, nao confirmacao financeira nem papel impresso.
- **Delivery nao imprime ao finalizar/criar o pedido.** O botao **Preparar**
  no PC ou no celular salva a intencao, coloca os destinos na fila confiavel
  e so confirma **Preparando** depois da persistencia. Reenvio e reinicio
  retomam os mesmos IDs. Mesa, Comanda e Balcao conservam preparo imediato.
- A impressao usa a configuracao salva da mesma API/empresa. O ticket mostra
  **SEM INTERNET** e uma referencia `P-...`; nao cria QR de venda provisoria.
  Itens, montagem, observacoes, combos e destinos usam o preparo existente.
- Ao voltar a internet, a fila original confirma a venda na API. O recibo
  oficial remove a copia provisoria do PC. Se o Delivery ja entrou em preparo
  pela LAN, o PC primeiro reconcilia essa etapa por `confirmar_preparo_rede.php`,
  com transacao, validacao da empresa/pedido/etapas e reserva da outbox.
  Nenhum pagamento e alterado. O mesmo ID de impressao impede repetir o preparo.
  Respostas perdidas nao regridem etapas posteriores; falhas conservam o retrato
  no PC. A intencao tambem acompanha o recibo se a internet voltar no clique.
  O caminho Online existente e o modo Local conservam suas acoes normais.
- A API reserva a outbox ao PC selecionado **na transacao do pedido**. A rota
  e persistida antes da primeira tentativa HTTP e nao pode trocar para outro
  PC durante a indisponibilidade. Reinicio e perda de ACK retomam os mesmos IDs.
  O canal previamente identificado tambem fica salvo no celular, permitindo
  reservar pedidos novos durante uma reconexao temporaria ao mesmo PC/IP.
- Conflitos reais da API conservam a copia para conferencia; o ACK da LAN
  nunca conclui pagamentos, pedidos, abertura ou fechamento de atendimento.

Modo **Local**, APIs sem a nova capacidade e modelos recorrentes conservam
seus caminhos anteriores. Operacoes antigas ja tentadas sem reserva nao recebem
retroativamente impressao pela LAN: sua situacao pode estar ambigua na API e
outro PC pode ter recebido o preparo. Elas continuam na sincronizacao existente.
Sem o PC/rede local ou sem configuracao de impressora salva, o pedido nao e
apagado; a fila correspondente continua aguardando recuperacao.

## Validacao

Testes automatizados cobrem API indisponivel com WebSocket real, SQLite duravel
no celular, arquivos duraveis no PC, reenvio e ACK perdido, reinicio, isolamento
de empresa/API/executor, reconciliacao, deduplicacao, modo Local, configuracao
salva sem HTTP e paineis em 320x480 e 1280x720. O helper PHP foi validado em
fixture SQLite derivada do schema oficial, incluindo rollback e reserva.
Publicacao Online e impressao fisica no PC Windows dependem da atualizacao
dos aplicativos e da API; nao foram executadas neste ambiente Mac.


## Validacao do ajuste Delivery

Testes de protocolo, SQLite, WebSocket real, reinicio, reenvio, isolamento,
quadros e avisos em 320/430/1280 px, Mesa/Comanda imediatas e retorno da internet.
Fixture PHP em SQLite extraida do schema oficial verifica Aguardando sem
impressao, Preparo transacional, replay, rollback, executor, isolamento,
pedido cancelado, etapa posterior e financeiro inalterado. Sem DDL ou banco vivo.
O teste antigo `novo_pedido_delivery_test.dart` apresenta uma falha de fixture
por `UsuarioProvedor` ausente em Modular na modal ja existente; os arquivos da
modal e esse teste nao foram alterados neste ajuste. As verificacoes focadas
no novo fluxo, sincronizacao, impressao automatica e cache do quadro passaram.
Impressao fisica no Windows e publicacao na hospedagem nao foram realizadas.

## Correcao das duas vias e da etapa apos reconexao (09/10/2026)

Ao preparar um Delivery recebido pelo Wi-Fi, a central grava juntos o preparo
por destino e o comprovante de consumo/entregador. A via do comprovante usa a
impressora do caixa e a ultima configuracao salva da mesma API/empresa/usuario,
conservando itens, valores, pagamentos, telefone e endereco do retrato local.
As vias possuem IDs diferentes e estaveis. Cada envio ao spooler tem etapa
persistida; resultado incerto fica pausado para conferencia, sem reenvio cego.
A referencia provisoria nao gera QR de pedido oficial. Mesa/Comanda e os
caminhos normais Online/Local conservam seu transporte e momento de impressao.

A central confirmava o preparo na API39, onde esse endpoint nao existia.
Agora essa chamada usa API41 no mesmo host/IP. O celular tambem envia a
intencao de preparo separada do payload financeiro congelado; API41 confirma
a etapa na mesma transacao que cria/recupera o pedido e reserva o preparo ao
PC original. O recibo guarda `etapa_rede_confirmada`. Repetir a operacao nao
reinsere produtos nem regride etapas posteriores. O helper continua aceitando
chamadas separadas da central e do celular, com reserva e IDs idempotentes.

Para pedidos ja confirmados por versoes anteriores, o celular conserva o
retrato em Preparando e deduplica o ID oficial em Aguardando ate a reconciliacao.
A recuperacao tambem considera operacoes financeiras ja concluidas e avisa
as telas depois de confirmar a etapa. Falha nessa recuperacao nao impede
o envio dos pedidos novos. A central recupera copias preparadas antigas,
incluindo a via faltante do comprovante; preparo ja confirmado na impressora
continua deduplicado pelo mesmo ID.

Aplicacao: recompilar/atualizar sistemadevenda e sistemarestaurante e publicar
`apis_restaurantes/build/delivery_wifi_duas_vias_etapa_api41_20261009.zip`
na raiz da instalacao correspondente. Abrir a central conectada uma vez para
salvar a impressora do caixa e a configuracao antes de operar sem internet.
O pacote nao contem credenciais, conexao.php, schema ou dados da empresa.

Validacao: WebSocket real, SQLite, cache da impressora sem HTTP e isolado,
bytes ESC/POS do comprovante/endereco/pagamento, envio incerto pausado,
reenvio, reinicio, etapa na volta da internet, perda de resposta, caminhos
Local/Online existentes e transacao PHP real em SQLite extraido de schema.sql.
Sem acesso ao banco vivo, publicacao Online ou impressao fisica no Windows.
