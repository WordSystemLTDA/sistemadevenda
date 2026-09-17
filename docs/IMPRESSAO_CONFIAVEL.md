# Impressao da cozinha

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
