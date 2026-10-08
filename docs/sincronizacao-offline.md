# Pedidos offline do garcom

## Escopo implementado

- Carrinhos de mesas/comandas e de itens recorrentes usam SQLite no aparelho.
- Produtos, tamanhos, sabores, bordas, adicionais, retiradas, observacoes e quantidades
  selecionados ficam no mesmo registro duravel da operacao e dos comprovantes.
- Finalizar grava a operacao e limpa somente aquele carrinho na mesma transacao.
  Falha de armazenamento nao confirma a finalizacao nem apaga o carrinho.
- O catalogo e as consultas previamente sincronizadas podem ser usados sem o servidor.
  A primeira entrada e a primeira preparacao dos dados precisam de conexao.
- Uma sessao ja autenticada pode ser retomada offline no mesmo servidor/empresa/usuario.
  Rejeicao de autenticacao pelo servidor nao e tratada como falta de rede.
- Mesas e comandas livres na ultima consulta podem ser abertas offline. A abertura,
  cliente, observacao e produtos ficam salvos no aparelho e aparecem nas listas locais.
- Novas vendas de balcao, seus produtos e pagamentos podem ser registrados offline.
  Pagamentos seguintes permanecem vinculados a identidade local da venda original.
- Novos pedidos de Delivery direto usam rascunho duravel no aparelho quando a API
  anuncia `offline_delivery: 1`. Produtos, endereco e pagamentos seguem juntos na
  operacao; a lista permite retomar pedidos identificados como `No aparelho`.
- Edicao cadastral, agendas de Recorrentes, fechamento, exclusoes, cancelamentos e
  alteracoes/pagamentos de atendimentos preexistentes continuam online. Esses fluxos
  precisam consultar o estado atual para nao sobrescrever outro atendimento ou cobrar
  um pagamento ja recebido. Abrir offline nao reserva o recurso
  nos outros aparelhos: a confirmacao depende da verificacao no servidor.

## Aberturas e vendas offline

A API anuncia `abertura_offline: 1` em `sincronizacao/estado.php` e fornece as
versoes de mesas/comandas e o caixa atual. E necessario conectar uma vez depois
de atualizar a API para preparar esses dados. Sem essa capacidade, o app preserva
as aberturas online antigas, mas nao inventa uma reserva offline sem verificacao.

Cada abertura recebe uma identidade `local:` persistente. A sincronizacao confirma
a abertura antes de enviar os produtos. O servidor devolve o ID e a versao reais;
os produtos fazem referencia ao recibo original, nunca apenas ao numero da mesa ou
comanda. O numero definitivo do pedido e aplicado ao comprovante apos confirmacao.

A versao do recurso inclui seu historico. Se ele foi ocupado, encerrado ou alterado
enquanto o celular estava desconectado, a abertura fica em conflito, mesmo que o
recurso esteja livre novamente. Os produtos dependentes nao sao enviados nem
impressos automaticamente. Arquivar a abertura nao libera esses produtos.

Vendas de balcao recebem identidade `venda-local:`. O recibo, os itens e o pagamento
sao gravados na mesma transacao no servidor. O caixa capturado na preparacao e
comparado com o atual: troca de caixa gera conflito. Pagamentos de uma venda
cancelada ou com abertura em conflito tambem exigem conferencia. Nao se deve
registrar manualmente a mesma venda no servidor enquanto ela estiver pendente.

O Delivery direto usa identidade `delivery-local:` e recebe numero definitivo somente
depois do recibo. A transferencia do carrinho para o rascunho e a confirmacao para a
fila sao transacoes SQLite; o snapshot permanece para consulta depois de enfileirado.
Uma vez enfileirado, o pedido nao e editado silenciosamente. Reenviar o mesmo ID
recupera o recibo, inclusive quando a resposta do primeiro envio se perdeu.
Clientes, enderecos e formas de pagamento precisam ter sido preparados enquanto
conectado. Dados novos de outro aparelho nao podem ser consultados durante uma queda.
Em 08/10/2026, a finalizacao quitada do Delivery na API39 passa a preencher
explicitamente os campos obrigatorios de `vendas`, inclusive quando nao ha nota
fiscal. O INSERT anterior omitia `id_consulta` e outros campos sem DEFAULT:
com SQL estrito, a transacao era rejeitada e o pedido ficava `No aparelho`.
Endereco e observacao do pedido acompanham a venda. Nenhuma estrutura do banco
ou regra de pagamento foi alterada.

Depois de gravar o recibo valido, a fila libera o Delivery local e solicita uma
atualizacao imediata da tela de origem, alem do aviso `Delivery` ao PC pela rede.
O pedido confirmado fica `Pendente` na primeira etapa ativa da empresa
(Aguardando na configuracao apresentada). Recibos incompletos e falhas HTTP
mantem o pedido duravel; o motivo da ultima falha fica visivel na pendencia.
O reenvio conserva a identidade e os dados originais. O erro temporario de envio
e removido quando a API confirma, sem esconder outros erros de sincronizacao.

Na correcao do reenvio em 08/10/2026, `delivery/inserir_produtos.php` gera o
hash dos itens do envio transacional com random_bytes. A hospedagem pode
conservar seu conexao.php antigo sem a funcao gerarHash; essa ausencia causava
HTTP 503 durante a insercao. A rota direta continua usando o gerador Local.
O teste MariaDB agora nao injeta gerarHash no bootstrap, cobrindo essa publicacao.
O botao Reenviar consulta o estado persistido depois da tentativa e informa
confirmacao ou pendencia. Identidade, snapshot e pagamentos nao sao substituidos.

`sincronizacao/falha_operacao.php` preserva os conflitos de negocio e classifica
falhas internas de estrutura, dependencia e banco ocupado. Uma referencia
aleatoria correlaciona a mensagem da tela com o error_log da hospedagem.
O log inclui codigo SQL, campo rejeitado e arquivo/linha quando disponiveis,
sem SQL, parametros ou dados do pedido. A rota de operacao anuncia o header
`X-Garcom-Sincronizacao: api39-20261008-reenvio-2`, permitindo conferir a
publicacao sem enviar um pedido real. Nao executa DDL ou reparo no banco.

Na correcao seguinte de 08/10/2026, o pedido com Marmita, Mais e Ovo reproduziu
outras duas falhas na gravacao dos complementos. A montagem ainda chamava
`gerarHash()` no helper compartilhado, mesmo quando o item principal ja tinha
hash independente do conexao.php. O helper agora conserva o gerador Local
quando existe e usa random_bytes quando ausente. Os adicionais recebiam kit
null interpolado como string vazia, recusada por MariaDB em modo estrito.
`inserirPacotes` normaliza produto avulso para kit zero e preserva IDs de kits.

Falhas de ingrediente e adicional conservam a excecao original ate o protocolo
transacional. Assim, erros SQL chegam ao log com sua causa e rejeicoes de
tarifa chegam como validacao, sem serem substituidos por falha generica.
Chamadores diretos continuam recebendo sucesso/mensagem e conservam o fluxo
existente. Nao ha alteracao de schema, valores ou dados de pedidos ja salvos.

A suite MariaDB descartavel reproduziu as duas falhas antes das correcoes e
confirmou depois a Marmita de R$ 20,00 + Mais R$ 5,00 + Ovo R$ 3,00 na etapa
Aguardando, com os tres ingredientes, adicional, pagamento e preparo no
mesmo recibo. Cobre SQL estrito/permissivo, Mais gratuito, kits, reenvio sem
duplicacao e rollback de complemento invalido. O teste Local verifica que o
gerador existente continua sendo utilizado. 117 testes Flutter de fila,
finalizacao, confirmacao Online/Local e atualizacao da tela passaram.

Publicar os arquivos do pacote
`build/correcoes/api39_delivery_montagem_aguardando_20261008.zip`, com backup
e conservando conexao.php. O header passa a informar
`X-Garcom-Sincronizacao: api39-20261008-delivery-montagem-3`. Reenviar a mesma
pendencia existente depois da publicacao; nao recriar o pedido. Esta correcao
e no PHP e nao exige mudanca adicional no app ja atualizado. As referencias
836bf2bd061b8659 e 04adc6a4573ead8e nao estavam nos logs locais; nao houve
acesso ao error_log remoto nem publicacao na hospedagem nesta verificacao.

O endpoint atual de busca de clientes retorna no maximo 15 resultados por consulta;
o preparo inicial nao representa o cadastro inteiro. Consultas e enderecos ja
carregados ficam disponiveis, e a busca local aceita nome, razao social, ID e celular
com ou sem mascara. Cadastrar um cliente/endereco novo continua exigindo conexao.

## Seguranca e sincronizacao

Cada operacao recebe um identificador aleatorio persistente. A API grava o recibo
em `garcom_operacoes` na mesma transacao dos itens e complementos. Repetir o
identificador com o mesmo conteudo recupera o recibo anterior; nao insere novamente.
Um identificador com conteudo diferente e recusado.

O envio informa o ID real de `comandas_pedidos` e uma versao calculada com sua
identidade, data/hora de abertura e hash. A API bloqueia o registro para atualizar,
confere empresa, mesa/comanda, status Andamento e a ausencia de outro atendimento
ativo no recurso. Um pedido antigo nunca e redirecionado para a comanda nova.

Atendimento encerrado, transferido ou produto/opcao removidos geram conflito.
Os dados ficam no aparelho, sem impressao automatica. A tela de pendencias permite
conferir e arquivar explicitamente; arquivar nao apaga o registro nem relanca os itens.
O botao **Excluir da sincronizacao** retira somente a pendencia local recusada e
preserva uma copia tecnica. Nao cancela um pedido nem estorna pagamentos no servidor.
Conflitos de conta encerrada, transferida ou recurso reutilizado nao oferecem reenvio
ou retorno ao mesmo carrinho. Os outros atendimentos continuam sincronizando.
Resposta perdida e recusa explicita sao estados diferentes: sem confirmacao segura
da API, a operacao conserva ID, payload e tentativas e nao pode ser copiada ao carrinho.
A recuperacao de uma recusa editavel e o arquivamento original fazem parte do mesmo
commit, serializado com o envio automatico, evitando duas copias enviaveis.
Rascunhos de carrinhos bloqueados/encerrados tambem ficam disponiveis nessa tela.
Antes de fechar um atendimento pelo app, seus pedidos pendentes devem ser resolvidos.

O transporte verifica o IP da API, nao exige internet publica. Ha retomada periodica
(15 segundos enquanto o processo executa), ao mudar a rede, ao reconectar o socket e
ao retornar ao app. Ao retomar apos suspensao ou mudar de rede, o canal antigo e
renovado sem esperar seu timeout. Pedidos prontos nao aguardam o preparo completo do
catalogo para iniciar envio. Consultas de produtos consultam o servidor quando ha
conexao; a copia persistida e usada durante falha de rede. O catalogo completo tem
revisao periodica (intervalo de dois minutos) ou apos aviso de alteracao.
Imagens ainda nao visitadas podem exibir o placeholder sem rede.

### Prioridade das telas e atualizacao do catalogo

Enquanto conectado, a abertura do cardapio consulta produtos e categorias atuais
em paralelo. Nao le nem decodifica o catalogo SQLite antes dessas requisicoes;
o fallback local continua disponivel se a rede falhar. A resposta atual continua
sendo persistida para a proxima queda de conexao. Nao ha cache de produtos entre
entradas na tela nem cache permanente do fallback de montagem do desktop.

Somente a aba visivel reconsulta produtos. Avisos de alteracao disparam uma leitura
e, mesmo sem aviso, ha conferencia 5 segundos depois da consulta anterior, enquanto
o app/tela estiver ativo. Requisicoes simultaneas da mesma atualizacao sao agrupadas;
uma resposta identica nao redesenha a lista. Ao voltar a uma aba, ela consulta o
servidor mantendo rolagem e busca. Itens ja lancados no carrinho nao sao reprecificados
silenciosamente; a atualizacao reflete o catalogo para novos lancamentos.

O preparo da copia offline roda separado da verificacao de estado e da fila de
pedidos. O transporte limita a uma consulta de preparo por vez, ate terminar de
receber o corpo da resposta, e da prioridade a consultas da tela e envios. Nao interrompe um POST
nem compartilha respostas entre requisicoes. No preparo, listas sao verificadas
no maximo uma vez por minuto, catalogo a cada dois minutos e formas de pagamento
a cada cinco minutos; avisos de cadastro invalidam o preparo correspondente.
Esses intervalos nao sao cache das consultas feitas pela tela online.

Produtos simples marcados pela API com `detalhesCompletos: true` dispensam outra
consulta individual no preparo offline. APIs antigas e produtos configuraveis
mantem a leitura completa. Falha no preparo conserva o ultimo catalogo valido;
seu commit tambem preserva consultas frescas recebidas pela tela durante o preparo.
Troca de conta e encerramento do sincronizador cancelam consultas auxiliares.

Validacao de desempenho: `tests/catalogo_garcom_performance_test.php` da API usa
SQLite isolado e confirma 6 consultas para uma pagina de 15 pizzas (antes, 20),
incluindo preco novo em uma segunda requisicao e isolamento das empresas 32/33.
Na validacao final desta otimizacao, os 986 testes Flutter passaram; a analise
dos 23 arquivos Dart alterados/adicionados ficou sem problemas. Passaram tambem
os cinco scripts PHP de catalogo, contexto, montagem, bordas e conferencia de
valores. Os testes incluem Dio consumindo corpos lentos, cancelamentos, respostas
de erro, atualizacao financeira durante preparo e consultas sem leitura local
antes do HTTP. Nenhuma impressora fisica ou aparelho de producao foi utilizado.
Isso mede consultas, nao latencia no Wi-Fi/iPhone do estabelecimento.
No aparelho, conferir alteracao de preco, inclusao e desativacao de produto com
o cardapio aberto; alternar categorias; suspender/retomar o app; e repetir com a
rede desligada apos preparar o catalogo. Conferir que uma fila grande de preparo
nao impede abrir a tela nem enviar um pedido. A duracao do HTTP ainda depende do
servidor e da rede; o intervalo de 5 segundos nao e garantia de resposta nesse prazo.

Filas/cache sao separados por servidor/empresa/usuario. Sair da conta nao apaga pedidos
pendentes; entrar novamente na conta original permite retoma-los. Nao limpar os dados
do aplicativo, desinstalar ou restaurar seu banco a uma copia antiga com pedidos pendentes.

## Impressao

Comprovantes somente entram na fila de impressao depois do commit confirmado pela API.
Usam o destino e o ID de requisicao originais. O socket consulta comprovantes sem ACK
antes de reenviar e exige o protocolo de impressao 2 ja existente no servidor desktop.
Confirmacoes ficam registradas no SQLite (ou no fallback legado) para impedir
recriacao apos reinicio. Quando a API devolve `impressao_persistida: true`, o preparo
ja esta na outbox do servidor, gravada junto do pedido; o celular nao envia outra via.

O app diferencia pendencia de pedido de pendencia de impressao. Uma impressora fisica
sem papel ou sem energia ainda exige intervencao; ACK nao garante papel entregue.
Nao enviar manualmente o mesmo pedido pela bancada sem antes conferir sua pendencia.

O indicador do cabecalho observa tanto a API quanto o socket: API online com o canal
da cozinha desconectado nao aparece como sucesso completo. A tela de envio informa
separadamente servidor de dados, canal da cozinha, disponibilidade do cardapio offline
e horario da ultima atualizacao, preservado entre reinicios. Conflitos aparecem antes
do diagnostico; rascunhos bloqueados tambem sinalizam atencao no cabecalho.

`Sincronizar agora` tenta recuperar o canal da cozinha imediatamente, sem aguardar
as consultas da API e sem criar uma segunda via. Toques repetidos compartilham a mesma
tentativa. A recuperacao automatica tambem independe do sucesso da consulta de catalogo.
Desconexao intencional continua sendo respeitada pelo processamento da fila.

## Tela apagada

O app nao desconecta intencionalmente o socket ao ficar inativo. No iOS, cada envio
pede uma extensao limitada com `beginBackgroundTask`, encerrada no termino ou na
expiracao. Isso nao mantem o processo vivo indefinidamente. iOS e Android podem
suspender ou encerrar aplicativos; a fila retoma quando o processo volta a executar.
Nao existe garantia de sincronizacao imediata com o aparelho suspenso/desligado.

Referencia: [execucao em segundo plano no iOS](https://developer.apple.com/documentation/uikit/extending-your-app-s-background-execution-time).

## Implantacao coordenada

1. Fazer backup e verificar as estruturas de sincronizacao/impressao ja definidas
   no `schema.sql` da API, incluindo `garcom_operacoes`. Se a instalacao ainda nao
   as possui, provisionar somente essas estruturas pelo processo controlado.
   Nao executar o schema completo sobre um banco existente. Nenhum endpoint faz DDL.
2. Publicar `sincronizacao/{estado,operacao,operacoes,recibo,delivery,versao_atendimento}.php` e os arquivos alterados:
   `comandas/inserir_produtos.php`, `mesas/inserir_produtos.php`,
   `funcoes/sabores/inserir.php`, `cardapio/listar_por_id_comanda.php` e
   `categorias/listar.php`, todos em `api_restaurantes_venda/api37/`.
   Para abertura e venda offline, incluir tambem
   `sincronizacao/{aberturas,vendas}.php` e `balcao/pagar_pedido.php`.
   Para Delivery offline, incluir `delivery/inserir_produtos.php` e
   `impressao/fila_transacional.php` (raiz da API), preservando a fila transacional
   ja provisionada. Publicar tambem os dois recebimentos
   `api_desktop/1.0.01/{mesas,comandas}/pagar_pedido.php` com seu helper
   `funcoes/pedidos/recebimento_transacional.php`: eles adquirem o mesmo bloqueio
   do envio de itens antes de calcular os totais, protegendo fechamento simultaneo.
   Essa extensao reutiliza `garcom_operacoes`; nao exige nova alteracao de schema.
   Na instalacao local atual, a API fica em um repositorio Git separado do aplicativo:
   atualizar somente o repositorio Flutter nao atualiza o servidor PHP.
3. A conexao Online do aplicativo usa `api39` em `bigchef.com.br`.
   Publicar o mesmo contrato nessa versao da hospedagem; atualizar o checkout
   local nao publica a API online.
   A leitura de mesas e comandas usa `sincronizacao/versao_atendimento.php` para
   calcular a versao sem carregar o modulo de operacoes ou a fila de impressao.
   Publicar esse helper junto com `cardapio/listar_por_id_comanda.php`.
   A versao calculada conserva o contrato usado na validacao do envio de pedidos.
4. Manter o servidor desktop com recibos/confirmacoes duraveis do protocolo de impressao 2.
5. Instalar o app atualizado, entrar conectado e aguardar a preparacao do catalogo.
   Um servidor sem o novo contrato nao recebe lancamentos pela fila.
6. Homologar no aparelho e impressora reais antes do atendimento em producao.

Para as otimizacoes de catalogo de 22/09, publicar tambem em
`api_restaurantes_venda/api37/` o novo `funcoes/catalogo_listagem.php`,
`funcoes/listar_pacotes.php`, `conexao.php` e os endpoints de `produtos/` alterados:
`listar.php`, `listar_por_categoria.php`, `listar_por_id.php`,
`listar_opcoes_pacotes_por_id.php`, `listar_acompanhamentos.php`,
`listar_adicionais.php`, `listar_itens_retirada.php`, `listar_sabores_de_borda.php`
e `listar_tamanhos_pizza.php`. O helper e os endpoints devem ser publicados juntos.
Em `conexao.php`, aplicar somente a remocao da consulta DNS desnecessaria,
preservando as credenciais e configuracoes especificas do servidor de destino.
Nao ha nova tabela, coluna ou migracao para essa otimizacao.

Na `api39`, publicar juntos `funcoes/filtro_produtos_cardapio.php`,
`funcoes/configuracao_cardapio.php`, `categorias/listar.php`,
`produtos/listar.php`, `produtos/listar_por_categoria.php` e
`config_bigchef/listar.php`. Os filtros e a leitura da configuracao acompanham
a propria API do app, evitando erro 500 quando os helpers correspondentes do
desktop nao foram publicados. As consultas continuam restritas a empresa da
sessao e os filtros de produtos ativos e personalizados permanecem iguais.

Para pedidos e impressao Online em 08/10/2026, publicar tambem
`impressao/{fila_transacional,listar_pendentes,confirmar_recebimento}.php` e
`funcoes/pedidos/sequencia_operacional.php` dentro da API39, junto com os
recebimentos e `sincronizacao/operacoes.php` alterados. Os helpers usam a
implementacao desktop quando presente e fornecem o mesmo contrato quando
ela nao foi publicada. Nao mudam o fluxo Local nem criam tabelas na requisicao.

O celular continua gravando pela API online, com recibo para retomar falhas.
O PC no papel SERVIDOR consulta a outbox da API39 na mesma empresa autenticada,
salva antes de confirmar o recebimento e processa a impressao automaticamente.
As telas sao invalidadas por avisos da rede e pelos lotes recuperados da API.
Filas de impressao agora carregam o escopo Online para impedir envio pela
conexao Local ou por outra empresa/API. Recompilar os dois apps e publicar
o pacote `build/correcoes/api39_online_pedidos_impressao_20261008.zip`.

Para a confirmacao de Delivery quitado, publicar
`api_restaurantes_venda/api39/sincronizacao/delivery.php` do pacote
`build/correcoes/api39_delivery_confirmacao_online_20261008.zip` e instalar
o app do garcom recompilado. O desktop conserva o protocolo existente; nesta
correcao foi acrescentada cobertura de teste do aviso Delivery. Depois da
publicacao, usar Tentar novamente na pendencia existente para recuperar o
mesmo pedido. Nao recriar nem registrar manualmente o pedido pendente.

O pacote `build/correcoes/api39_delivery_reenvio_servidor_20261008.zip`
substitui o pacote de confirmacao para esse fluxo. Publicar os quatro PHP juntos:
`sincronizacao/{operacao,falha_operacao,delivery}.php` e
`delivery/inserir_produtos.php`, preservando o conexao.php da hospedagem.
Atualizar o app do garcom conservando os dados locais e reenviar a pendencia
existente. O teste de falhas PHP verifica status, correlacao da referencia e
ausencia de dados privados nas respostas/logs; 118 testes Flutter validam o
reenvio com falha/recibo incompleto e confirmacao Online/Local, alem dos fluxos
de finalizacao, fila duravel e atualizacao da tela.

Nao foram alterados dados ou provisionadas tabelas no banco de producao nesta tarefa.
O banco SQLite do aparelho migra da versao 1 para 2 automaticamente, apenas adicionando
o codigo do conflito as operacoes ja existentes; carrinhos, recibos e filas sao mantidos.

## Verificacao

`flutter test` cobre os fluxos existentes, SQLite, recuperacao apos fechar/reabrir o
banco, resposta perdida, conflitos, separacao de contas, erro de disco e layouts.

`test/essencial/sincronizacao/servidor_test.php` exige uma instancia MariaDB descartavel
em `/private/tmp/garcom-mariadb-test/`, socket exclusivo e o schema canonico provisionado.
Recusa outro datadir. Ele insere fixtures sinteticas e valida transacao, rollback de
complementos, concorrencia, mesa/comanda e resposta repetida apos fechamento.
Tambem cobre abertura offline, recurso reutilizado, vendas, pagamentos parciais,
cancelamento e mudanca de caixa. A suite Flutter verifica a ordem das dependencias,
compatibilidade online com API antiga, perda de resposta e recibos incompletos.

`apis_restaurantes/tests/executar_delivery_mysql_test.py --mysql-base
/Applications/XAMPP/xamppfiles` provisiona uma instancia temporaria exclusiva
a partir do schema canonico e executa `sincronizacao_delivery_mysql_test.php`.
Exige MariaDB/PHP nessa instalacao, usa apenas socket Unix e encerra/remove a
fixture ao terminar. O PHP recusa outro datadir e nunca carrega conexao.php.
Cobre quitacao em SQL estrito/permissivo, entrada em Aguardando, dados da venda,
recibo repetido sem duplicar financeiro/preparo, pagar depois e rollback.
Os testes Flutter exercitam confirmacao e atualizacao em Online/Local, falha 503,
recibo incompleto e reenvio do mesmo snapshot. O desktop usa WebSockets de
loopback reais para verificar o aviso Delivery e o isolamento da empresa.

Homologacao manual obrigatoria: desligar Wi-Fi apos carregar o atendimento; montar
pizza completa e finalizar; reiniciar o app; reconectar; conferir um unico lancamento
e comprovante. Repetir encerrando/reabrindo a comanda pela bancada antes da reconexao:
o pedido antigo deve ficar em conflito, sem itens nem impressao na nova comanda.
Repetir com uma mesa/comanda inicialmente livre, abertura offline seguida de itens,
e com uma nova venda de balcao. Conferir a numeracao definitiva e um unico
comprovante apos reconectar. A impressora fisica ainda requer essa homologacao.

## Auditoria de 12/09/2026

- Suite completa do aplicativo: 328 testes aprovados, incluindo 12 novos testes.
- API em MariaDB descartavel, sem conexao TCP: 17 cenarios aprovados.
- Nucleo desktop de impressao: 9 testes aprovados, sem acessar impressora fisica.
- Analise estatica dos 10 arquivos Dart alterados/adicionados: sem problemas.
- Compilacao iOS debug sem assinatura: concluida em `build/ios/iphoneos/Runner.app`.
- Consulta de estado ao servidor local: HTTP 200 em 173 ms; protocolo e capacidade
  de abertura offline presentes. Nenhum pedido real foi criado ou alterado.
- Canal WebSocket local: conectado em 57 ms e mantido por 60 segundos, com ping a
  cada 5 segundos, sem comandos de pedido ou impressao. E uma observacao pontual,
  nao uma garantia de disponibilidade continua da rede.
- Testes com socket de loopback validaram queda real, reconexao automatica e
  recebimento de atualizacao de comanda, alem de nova tentativa manual imediata.
- Retomada de sessao online/offline, reabertura do aplicativo, pausa/retorno e
  falha do monitor de rede foram verificados em testes automatizados. Sair da
  conta continua exigindo autenticacao; nao libera credenciais novas offline.
- Capturas conferidas em `build/validacao_ui`, com telefone pequeno, tablet e
  fonte ampliada. Indicador permanece no cabecalho; conflitos aparecem primeiro.

Nao houve instalacao desta compilacao no iPhone nem teste com driver/impressora
fisicos. Antes de liberar a versao para atendimento, executar a homologacao manual
acima com uma comanda de teste e conferir papel, quantidade, sabores, bordas,
adicionais, mesa, observacoes e ausencia de lancamentos/comprovantes duplicados.
Nao desinstalar o aplicativo para atualizar enquanto houver pedidos pendentes.

## Auditoria de 22/09/2026

- Suite completa do aplicativo: 936 testes aprovados, incluindo busca e preservacao
  de clientes offline, retomada de pagamentos parciais e protecao de contas encerradas.
- API em MariaDB descartavel: 22 cenarios aprovados, incluindo fechamento,
  reutilizacao de mesa/comanda, duplicidade e recebimento concorrente.
- Delivery offline em SQLite descartavel: 7 grupos aprovados, com rollback de
  itens/recibo, pagamento dividido, troco, parcelas, caixa e isolamento de empresa.
- Fila PHP de impressao: rollback, reenvio, recuperacao e ACK duravel aprovados.
- Analise estatica dos 39 arquivos Dart alterados/adicionados: sem problemas.
- Compilacao iOS debug sem assinatura concluida. Nao instalada no aparelho.

Tambem homologar novo Delivery: preparar cliente/endereco conectado, cortar a rede,
montar pedido com adicionais/peso, registrar pagamento parcial, fechar/reabrir o app
e retomar em `No aparelho`. Conferir saldo, desconto/acrescimo e troco; confirmar,
reconectar e conferir um unico pedido, seus pagamentos e a impressao. Repetir com
resposta perdida e com caixa fechado/trocado: os dados devem permanecer salvos para
conferencia, sem gerar recebimento em caixa diferente automaticamente.

Esses testes usam fixtures e nao substituem validacao com impressora, servidor e
aparelho reais. Nao foram publicadas APIs nem modificados dados de producao.
