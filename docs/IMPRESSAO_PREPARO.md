# Envio de comprovantes de preparo

## Fluxo do aplicativo

- A montagem completa (tamanho, sabores, bordas, adicionais, retiradas e observacoes) e serializada antes da finalizacao.
- A venda e registrada uma vez. Depois, todas as mensagens de impressao sao gravadas em lote no armazenamento local antes do envio e da limpeza do carrinho.
- Falhas na impressao ou na limpeza, enquanto a tela permanece aberta, nao repetem o lancamento da venda.
- Mensagens nao enviadas aguardam a conexao. O endereco do servidor e preservado para nao encaminhar pendencias a outra cozinha ao trocar a conexao.
- Antes de escrever no socket, o estado passa a `semConfirmacao`. Apenas o ACK de sucesso com o mesmo `idRequisicao` remove a pendencia automaticamente.
- Pendencias nao expiram e nao sao descartadas pelo limite da antiga fila de atualizacoes de tela.
- A fila antiga e migrada como `semConfirmacao`, pois nao havia registro confiavel de quais mensagens ja tinham sido enviadas.
- Em `Impressoes pendentes`, o atendente pode conferir com a cozinha, autorizar reenvio ou confirmar recebimento manual. Reenvio repete apenas o comprovante, nunca a venda.

## Limites do protocolo atual

O ACK do servidor existente nao comprova a saida fisica do papel. Em destinos remotos, pode confirmar apenas o encaminhamento. O aplicativo nao consegue detectar papel esgotado, falhas do driver nem falhas posteriores a esse ACK.

O servidor atual tambem nao mantem deduplicacao persistente de todas as impressoes concluidas. Por isso, mensagens ja enviadas ou com erro nao sao reimpressas automaticamente: uma confirmacao perdida poderia duplicar pedidos na cozinha.

Venda HTTP e impressao por socket nao formam uma transacao atomica. Se o processo for encerrado entre a confirmacao da venda e a persistencia da impressao, e necessario conferir o pedido gravado. Garantias atraves dessa janela exigem outbox e idempotencia no backend, nao apenas no aplicativo.

## Validacao antes de publicar

1. Finalizar produto comum e pizza montada em mesa, comanda e balcao.
2. Repetir uma pizza com bordas, adicionais, retiradas e observacoes.
3. Conferir impressoes em destinos diferentes no mesmo pedido.
4. Desconectar a rede antes de finalizar, conferir a pendencia e reconectar.
5. Simular falta de confirmacao e conferir que nao ha reenvio automatico duplicado.
6. Conferir fisicamente os comprovantes nos computadores e impressoras usados pela cozinha.

Testes automatizados usam armazenamento e socket simulados. Nao enviam trabalhos para impressoras reais.
