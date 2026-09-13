# Melhorias do atendimento: etapa 1

Data: 12/09/2026. Base: documento Word e capturas enviados pelo cliente,
codigo do aplicativo e API local. Esta entrega implementa a primeira etapa
autorizada; nao representa a implementacao de todos os requisitos do Word.

## Entregue

- Indicadores no Inicio e no menu lateral, para administradores.
- Hoje, ultimos 7 dias, ultimos 30 dias e periodo personalizado de ate 90 dias.
- Filtro Todos / Mesas / Comandas / Balcao, sem nova requisicao ao trocar canal.
- Quantidade de atendimentos, consumo registrado, cancelamentos, horario de pico,
  comandas/mesas do periodo ainda em andamento e em fechamento.
- Graficos por hora e por dia; distribuicao por tipo de atendimento.
- Atualizacao manual, ao retomar o app e a cada minuto com a pagina visivel.
  Consultas antigas sao descartadas ao mudar filtro/usuario ou sair da pagina.
- Consulta anterior identificada como offline em falhas de conexao. Somente o
  ultimo periodo consultado, por servidor/empresa/usuario, por ate 24 horas.
  Sem cache desse periodo, informa indisponibilidade em vez de inventar zeros.
- Tempo aberto dos detalhes calculado pela data original, nao pelo tempo na tela.
- Falha de consulta nos detalhes libera carregamento e permite repetir.
- Confirmacao de fechamento direto nao reabre a cada atualizacao da pagina.
- Fechamento recusado nao dispara comprovante; botoes da confirmacao quebram
  linha em telas estreitas.

## Significado dos numeros

| Indicador | Regra |
| --- | --- |
| Periodo | Dias civis completos, no horario do servidor. Nao e o turno do caixa. |
| Atendimentos | Aberturas de `comandas_pedidos` e registros de balcao em `vendas`, sem cancelados. Uma reabertura com outro ID e outro atendimento. |
| Canal | Comanda vinculada a mesa conta como Comanda, uma unica vez. Mesa e atendimento sem comanda. Vendas de fechamento de mesa/comanda nao contam novamente como balcao. |
| Consumo registrado | Soma dos itens atuais dos atendimentos abertos no periodo, mais subtotal das vendas de balcao do periodo. Exclui atendimentos cancelados. Inclui contas abertas e nao representa faturamento recebido, lucro ou fechamento de caixa. |
| Cancelados | Atendimentos iniciados no periodo cujo status atual e Cancelada. Aparecem separados, fora dos graficos de movimento valido. |
| Pico | Hora com mais aberturas validas acumuladas no periodo. Em empate mostra a primeira. Ausencia de horario nao e convertida em meia-noite. |
| Em andamento/fechamento | Situacao atual das mesas/comandas iniciadas no periodo selecionado. Nao e ocupacao de todas as mesas do restaurante. |
| Atualizado | Instante da consulta ao servidor. A visao historica pode mudar por novos itens, transferencias ou cancelamentos posteriores. |

Os valores monetarios trafegam como centavos inteiros. Dias e horas sem movimento
sao preenchidos com zero somente depois de uma consulta bem-sucedida.
Pedidos ainda apenas no celular nao sao adicionados aos totais do servidor.
Nao ha estimativa de tempo de preparo: impressao confirmada nao comprova inicio
de preparo, pedido pronto ou entrega ao cliente.

## Seguranca e compatibilidade

Endpoint novo: `api_restaurantes_venda/api1/indicadores/listar.php` (POST).
Sua implementacao esta no repositorio separado `sistema/apis_restaurantes`,
nos arquivos `indicadores/consulta.php` e `indicadores/listar.php`.

A API confere credenciais e usuario ativo, busca a empresa e o nivel no banco
e restringe niveis administrativos 0 e 1, conforme a regra existente no desktop.
Nao aceita um nivel ou empresa arbitrarios enviados como filtro. Os mesmos
limites de periodo sao validados no servidor. Consultas usam parametros SQL.

A visibilidade no celular e apenas conveniencia: a autorizacao real e na API.
Grupos personalizados de gerencia nao recebem acesso automaticamente nesta etapa.
Nao foi criada uma permissao nova nem alterado o cadastro de grupos existentes.
Revogacoes conhecidas (401/403) invalidam o cache. Offline nao e possivel descobrir
uma revogacao ocorrida no servidor; por isso a consulta guardada tem prazo limitado.

Reutiliza a autenticacao legada por credenciais no corpo, sem coloca-las em URL,
logs ou no cache do painel. A rede local atual usa HTTP. Migracao para sessoes
com tokens, armazenamento seguro e transporte TLS continua uma prioridade
separada; esta etapa nao resolve a arquitetura legada de autenticacao.

Nao grava pedidos, pagamentos ou eventos de impressao. Nao altera configuradores,
regras de preco, fila offline ou protocolo de impressao. Nao exige migracao de banco.
API antiga ou modo Online sem o novo endpoint mostra pedido de atualizacao,
sem bloquear o restante do aplicativo. A entrega de servidor aqui e a API1 local.

## Publicacao e conferencia no restaurante

1. Publicar pelo Git os dois arquivos novos da API no servidor local.
2. Gerar/distribuir a versao atualizada do aplicativo pelo fluxo habitual.
3. Entrar com administrador e abrir Inicio > Indicadores.
4. Comparar um dia conhecido com comandas/mesas e vendas de balcao do sistema.
   Conferir sobretudo atendimentos cancelados, reabertos e vinculados a mesa.
5. Abrir o mesmo periodo sem rede: deve aparecer a consulta anterior identificada.
   Reconectar e retomar: os dados devem ser atualizados sem repetir pedidos.
6. Com um usuario comum, confirmar a ausencia do atalho e recusa pela API.
7. Em horario combinado, homologar um pedido de teste na impressora fisica,
   incluindo desligamento/religamento do Wi-Fi e reentrada no aplicativo.

Os testes automatizados nao substituem a homologacao da impressora, do roteador
e do telefone reais. iOS/Android podem suspender processos com a tela apagada;
conexao permanente em segundo plano nao pode ser garantida. Validar retomada e
fila persistida e mais importante que pressupor um socket sempre aberto.
Medir a consulta com volume representativo antes de ampliar o periodo de 90 dias.

Verificacao de disponibilidade em 12/09/2026: o endpoint em `192.168.2.113`
respondeu HTTP 401 ao POST sem credenciais, como esperado. A rota ja estava
publicada nessa verificacao. Isso nao valida totais reais nem permissao de uma
conta especifica; nenhum pedido ou pagamento foi criado nesse servidor.

## Avaliacao e proximas etapas

| Area do material | Situacao nesta etapa | Proxima prioridade |
| --- | --- | --- |
| Visual e uso | Painel responsivo; detalhes com tempo real e recuperacao de erro. Configuradores preservados. | P1: conferir fluxo completo em aparelhos usados pelos garcons; reduzir espaco de imagens genericas sem perder area de toque. |
| Mesas e comandas | Identidade de atendimento e protecao contra reutilizacao cobertas pelos testes existentes. | P1: validar transferencias concorrentes e consumo por pessoa com o caixa. |
| Produtos e montagens | Busca, carrinho e recorrentes existentes preservados e incluidos na regressao. | P1: favoritos e indisponibilidade explicita, incluindo alteracoes feitas enquanto o celular estava offline. |
| Cozinha/bar | Testes da fila, reenvio e impressao existentes mantidos. | P1: eventos reais de aceito, em preparo, pronto e entregue por setor; alteracoes/cancelamentos identificados como novas comandas de producao. |
| Balcao | Venda/pagamentos offline existentes testados; indicador por canal. | P1: identificar retirada e separar visualmente pagamento de preparo. |
| Fechamento | Corrigido comprovante apos recusa de fechamento. | P1: homologar divisao por pessoa/item, pagamentos parciais e autorizacoes no caixa. |
| Conexao | Regressao de reconexao, persistencia, idempotencia e conflitos. | P0: homologacao fisica e auditoria da autenticacao legada; nada de promessa de zero falhas. |
| Estatisticas | Fluxo, pico e consumo com definicoes explicitas. | P2: indicadores financeiros reconciliados, produtos mais vendidos e tempos por etapa quando houver eventos confiaveis. |
| Diferenciais | Nenhum servico externo contratado/integrado. | P2: chamado de garcom, QR hibrido e sugestoes configuraveis. P3: voz/IA com revisao humana antes de enviar pedidos. |

As funcionalidades das proximas etapas nao foram declaradas ausentes em todo o
sistema desktop: exigem avaliacao dos respectivos modulos e contratos antes de
serem expostas no celular. Nao ativar pagamentos, transferencias ou cancelamentos
automaticos por IA sem autorizacao e trilha de auditoria.

## Referencias de mercado

Consulta em 12/09/2026, em fontes dos proprios fornecedores:

- A [Goomer](https://goomer.com.br/planos) apresenta QR Code, acompanhamento de
  pedidos, venda sugestiva e KDS. Sao referencias para etapas opcionais, nao
  integracoes adicionadas nesta entrega.
- O [Toast IQ](https://pos.toasttab.com/products/toast-iq) apresenta analise dos
  dados do negocio e sugestoes operacionais. Minha recomendacao para este app e
  consolidar os eventos e autorizacoes antes de adicionar um assistente de IA.

## Testes reproduziveis

Flutter: `flutter test --no-pub --no-test-assets`.
Novos cenarios: `test/modulos/indicadores`, `test/essencial/tempo_aberto_test.dart`
e `test/modulos/cardapio/detalhes_atendimento_test.dart`.

PHP: `test/modulos/indicadores/servidor_indicadores_test.php` e
`test/essencial/sincronizacao/servidor_test.php`, com o caminho do repositorio da
API como argumento. Executar SOMENTE na instancia descartavel configurada nos
scripts. Eles recusam outro datadir e podem limpar as tabelas dessa instancia.
