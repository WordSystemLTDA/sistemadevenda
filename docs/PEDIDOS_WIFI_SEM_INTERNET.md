# Pedidos pelo Wi-Fi durante queda de internet

Implementacao de 09/10/2026 para a conexao **Online / API41**. A API continua
responsavel por vendas, pagamentos e numeros oficiais. A rede Wi-Fi leva uma
copia provisoria do pedido ao PC e a fila confiavel de impressao da cozinha.

## Atualizacao necessaria

1. Publicar na raiz da API41 os arquivos do pacote
   `build/pedido_wifi_sem_internet_api41_20261009.zip` do projeto `apis_restaurantes`.
   O pacote contem `sincronizacao/estado.php`, `sincronizacao/operacoes.php`,
   `impressao/reserva_pedido_rede.php` e `impressao/fila_transacional.php`.
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
  Seus paineis exibem **Recebidos pelo Wi-Fi / Aguardando sincronizacao com a API**.
  O celular informa **Recebido pelo PC via Wi-Fi** depois desse ACK; isso
  significa recebimento duravel, nao confirmacao financeira nem papel impresso.
- A impressao usa a configuracao salva da mesma API/empresa. O ticket mostra
  **SEM INTERNET** e uma referencia `P-...`; nao cria QR de venda provisoria.
  Itens, montagem, observacoes, combos e destinos usam o preparo existente.
- Ao voltar a internet, a fila original confirma a venda na API. O recibo
  oficial remove a copia provisoria do PC. O mesmo ID de impressao impede
  repetir o preparo que ja foi executado.
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
