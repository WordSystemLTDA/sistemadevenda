# Impressao da cozinha

## Canal de atualizacao online (08/10/2026)

Com conexao `Online`, o app atualizado descobre o desktop `sistemarestaurante`
na mesma rede Wi-Fi, desde que ele esteja em `SERVIDOR`, autenticado na mesma
empresa e usando o mesmo dominio da API. UDP 9982 e WebSocket TCP 9980 sao as
portas padrao; o IP/porta salvos sao alternativa quando a descoberta nao funciona.
Dados e imagens continuam online, independentemente do IP do socket.

Na tela de configuracao, o modo Online permite salvar sem IP e porta locais.
Quando esses campos estiverem preenchidos, a conexao do socket ocorre em segundo
plano e sua falha nao mostra o aviso de indisponibilidade da API. O modo Local
continua exigindo IP e porta e informa quando o computador nao responde.

O canal tambem recebe comprovantes e confirmacoes de impressao da mesma
empresa/API, incluindo consultas de status e cancelamento no protocolo 2.
O pedido continua sendo confirmado pela API HTTP. A sincronizacao e automatica:
quando o telefone fica sem rede, conserva o pedido e retoma o mesmo ID ao reconectar.
Online nao depende de um servidor PHP/MySQL na rede local para gravar pedidos.

Para preparo com `impressao_persistida: true`, o computador consulta a outbox da
API39 online, persiste o lote no disco e so entao confirma o recebimento HTTP.
A fila do computador inicia a impressao e atualiza as telas. Avisos
`PreparoPendente` antecipam essa consulta; o polling recupera avisos perdidos.
Comprovantes de consumo e outras impressoes seguem pelo socket da rede.
Filas Local/Online ou de outra empresa/dominio nao sao adotadas entre modos.
Consulta de ACK perdido usa o mesmo ID, sem repetir uma via ja confirmada.

Atualizar ambos os apps e publicar os PHP da API39 do pacote
`build/correcoes/api39_online_pedidos_impressao_20261008.zip` na hospedagem.
Nao substituir `conexao.php`. O banco deve estar provisionado conforme o
schema oficial; esta correcao nao acrescenta DDL nem altera dados da empresa.
A API geral e as imagens do desktop continuam no endereco online habitual.


Validacao de 08/10/2026: 227 testes do celular (sincronizacao, impressoes,
configuracao e catalogo), 81 testes distintos do desktop (servidor, recuperacao,
roteamento Online, impressao e atualizacao) e testes PHP de publicacao isolada
com rollback, replay, empresa/executor e ACK. Analises Dart e lint PHP aprovados.
A hospedagem e a impressora fisica nao foram atualizadas/acionadas pelos testes.

## Revisao de 22/09/2026

Esta revisao substitui o limite de tentativas/consultas do historico abaixo.
O servidor continua tentando falhas de rede/configuracao com intervalo maximo
de um minuto. O celular continua consultando o estado, sem repetir a impressao
por ausencia de resposta. Somente `naoEncontrada` v2 permite reenvio do mesmo ID.
Pausas antigas exclusivamente por limite de consultas voltam a ser consultadas.

O executor grava uma etapa em andamento antes do driver. Queda durante esse
envio, timeout ou falha nativa ambigua exige conferencia; vias ja confirmadas
sao mantidas. O plugin atual nao diferencia abertura recusada de escrita parcial.

Operacoes duraveis do garcom enviam os comprovantes junto ao pedido. A API
atualizada grava a outbox na mesma transacao; o computador central a consulta
a cada dois segundos e assume somente apos salvar na propria fila. O socket
antecipa a consulta com `PreparoPendente`. Quando `impressao_persistida` e true,
o garcom nao cria um segundo envio de preparo no socket. Consumo/entregador e
APIs antigas conservam suas filas. A reserva da API pertence a uma identidade
persistente da instalacao central e nao expira automaticamente; troca de central
exige recuperar identidade e filas antes de assumir reservas antigas.
Publicar os dois apps e a API e provisionar o schema oficial para ativar a outbox.
O Delivery possui fluxos proprios; nao presumir que todo movimento usa a operacao
duravel de mesas/comandas/balcao.

Falha de leitura nao apaga a fila mobile: os dados ficam preservados para
recuperacao. Os testes desta revisao simulam transporte/armazenamento/spooler,
sem enviar pedidos ou imprimir no equipamento real.

## Instalacao

Esta correcao envolve os projetos `sistemadevenda` e `sistemarestaurante`.
Atualizar primeiro o servidor e os computadores que executam a impressao em
`sistemarestaurante`; depois instalar o aplicativo mobile atualizado.
Os executores anunciam `protocoloImpressao: 2` no registro de rede.
Um executor antigo fica pendente, com aviso de atualizacao, para impedir
reimpressoes repetidas enquanto ele ainda nao confirma nem deduplica envios.

## Recuperacao automatica

Revisao de 17/09/2026: sem destino/impressora ou com `Sem Impressora`, inclusive
em combos, nao gerar comprovante. O principal oferece limpeza em Impressoras;
o mobile oferece Limpar pendencias na tela de impressoes. Pedidos sao mantidos.

- O mobile salva o comprovante antes de registrar o pedido na API. Ele fica
  bloqueado para impressao ate a confirmacao do registro dos produtos.
- Depois disso, o envio permanece salvo ate a confirmacao de execucao.
- A cada 5 segundos, o aplicativo verifica as pendencias, com no maximo tres
  mensagens por ciclo. Consulta depois de 15 segundos e passa a um minuto;
  depois de tres consultas por sessao sem conclusao, pausa o acompanhamento.
  Ajuste de 17/09: novos envios elegiveis continuam em lotes de tres a cada
  50 ms, sem aguardar o ciclo de recuperacao. Eles precedem consultas antigas;
  mensagens ja enviadas continuam aguardando ACK, sem repeticao por lote.
  O executor atualizado serializa impressoes simultaneas sem tratar ocupacao
  normal como falha. Conserva uma chamada nativa ativa e espera limitada.
- O servidor salva o pedido antes de despachar e processa sequencialmente,
  no maximo tres registros por ciclo e tres tentativas por ID. Os intervalos
  de 15 segundos/um minuto e o limite sao persistidos, inclusive no reinicio.
  Consultar um ID nunca inicia uma impressao.
- O computador executor persiste os IDs concluidos e as partes ja aceitas
  pelo driver. A repeticao do mesmo ID devolve a confirmacao existente;
  uma falha parcial retoma as partes pendentes.
- A reconexao do mobile e do executor continua com intervalo crescente,
  limitado a 30 segundos, sem esgotar um numero maximo de tentativas.
- Ao retomar o aplicativo ou reiniciar o servidor, as filas sao recuperadas.
  A suspensao do aplicativo pelo sistema operacional pausa seu processamento;
  pedidos ja recebidos pelo servidor continuam sendo tratados por ele.

## Protocolo

Requisicao: `tipoImpressao: "1"`, `protocoloImpressao: 2`, `idRequisicao`
e `idEmpresa`, preservando todos os produtos, opcoes e destinos.
Consulta: `tipo: "ConsultarImpressao"`, mesmo ID e empresa.

Resposta: `tipo: "RespostaImpressao"`, `tipoResposta: "impressao"`,
`protocoloImpressao: 2`, mesmo ID e empresa, com `statusResposta`:

| Estado | Significado |
| --- | --- |
| `processando` | Salvo no servidor, ainda sem confirmacao do executor. |
| `naoEncontrada` | Servidor nao possui o ID; mobile pode reenviar o mesmo comprovante v2. |
| `erro` | Mantem pendente e tenta recuperar automaticamente. |
| `sucesso` | Executor aguardou o driver e persistiu a conclusao. |
| `pausada` | Limite ou resultado incerto; requer conferencia manual. |
| `dispensada` | Nenhum produto possui impressora vinculada. |
| `cancelada` | Impressao cancelada; o pedido continua registrado. |

`CancelarImpressao` usa o mesmo ID e empresa e conserva um registro de
cancelamento. O celular transmite esse controle ao reconectar, sem reenviar o
comprovante. A limpeza nao inclui pedidos cuja gravacao ainda aguarda confirmacao.
Uma via ja enviada ao driver pode sair; sem rede o servidor so cancela quando
receber o controle. Reenviar manualmente gera `retomadaImpressao`, token usado
uma unica vez para liberar novas tentativas, preservando etapas ja impressas.

O simples encaminhamento ao computador remoto nao produz sucesso.
Respostas de sucesso de servidores antigos nao encerram pendencias da cozinha.
Pedidos antigos sem historico v2 precisam de conferencia na migracao; nao ha
como deduzir se foram impressos anteriormente apenas pela ausencia de um ACK.

## Limites E Verificacao

O plugin Windows devolve `success` quando aceita os bytes para impressao;
isso nao e um sensor de papel impresso. Falta de papel, falha fisica, apagamento
dos dados locais e perda de energia precisam ser considerados na operacao.
Uma queda exatamente entre o aceite do driver e a gravacao da etapa ainda
pode deixar resultado incerto: o driver atual nao oferece consulta por ID.

Se a API nao confirmar o registro do pedido, o comprovante fica visivel como
`Registro do pedido sem confirmacao`. Ele nao e impresso automaticamente, para
nao preparar uma venda que pode ter sido recusada. Essa ambiguidade de HTTP
exige conferencia do atendimento; nao se deve repetir a venda automaticamente.

Testar em Windows com a impressora da cozinha: desconectar e reconectar a rede,
desligar e religar o executor, enviar pizza com opcoes e bebida para destinos
distintos, e confirmar que apenas os comprovantes pendentes sao recuperados.

Testes automatizados do nucleo desktop podem ser executados a partir do mobile,
sem compilar as dependencias de video do projeto desktop:

```sh
flutter test --no-pub --no-test-assets ../sistemarestaurante/test/impressao_confiavel_test.dart
```
