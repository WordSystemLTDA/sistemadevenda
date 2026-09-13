# Etapa 3: telas de atendimento e conferencia

## Escopo

Revisao das nove telas enviadas em 12/09/2026: detalhes de mesa/comanda,
abertura de mesa/comanda, listas de mesas/comandas, carrinho recolhido/expandido
e selecao de adicionais. A identidade do cabecalho e o espaco do indicador
global de sincronizacao foram preservados.

## Alteracoes

- Detalhes com identificacao, cliente, tempo real de abertura, acao principal
  de adicionar produtos e acoes secundarias em lista. Fechar conta e reabrir
  respeitam a situacao atual e continuam exigindo confirmacao.
- Edicao de mesa usa o ID da mesa, nao o ID da comanda, e atualiza os detalhes
  ao retornar. A consulta do formulario usa o tipo de atendimento correto.
- Formularios com campos opcionais, observacao para identificacao sem cadastro,
  botao separado da rolagem, protecao contra envio repetido e recuperacao de erro.
  Abertura sem acesso direto ao cardapio retorna a lista de atendimentos.
- Listas com superficie neutra, estados identificados por texto e cor,
  numero do atendimento, cliente, consumo permitido pelo perfil, mesa vinculada
  e tempos. Atendimento ainda local tem identificacao "No aparelho".
  Busca, filtros, QR Code, digitacao de codigo e NFC existente foram mantidos.
- Carrinho com destino, progresso da conferencia, observacao visivel, card verde
  apos conferencia e detalhamento de sabores, bordas, adicionais e valores.
  O botao de finalizar tem area propria e nao cobre o final da lista.
- Adicionais com menos, quantidade e mais na mesma linha. O espaco dos controles
  e reservado mesmo antes da selecao. Reduzir de uma unidade para zero desmarca
  o adicional. Selecao e calculos continuam usando o provedor existente.
- Pagina de produto sem blocos decorativos grandes ou imagem generica ampliada.
  Fotos cadastradas continuam disponiveis; erros de consulta oferecem tentativa
  novamente e respostas tardias nao alteram uma pagina descartada.
- Nome usado no preparo prioriza cliente cadastrado; na ausencia dele, usa a
  observacao. Mesmo tratamento no carrinho normal e no de itens recorrentes.

## Verificacao

- Suite completa Flutter: 406 testes aprovados.
- Analise estatica: sem erros ou warnings; cinco apontamentos informativos
  preexistentes em arquivos fora desta etapa.
- Compilacao iOS debug sem assinatura concluida com sucesso.
- Testes novos: visual_atendimento_test.dart, adicionais_inline_test.dart e
  carrinho_visual_test.dart.
- Geometria antes/depois de selecionar adicionais, recalculo de quantidade,
  conferencia persistida, visibilidade do total ao rolar, cadastro opcional,
  edicao de mesa, falha e nova tentativa, resposta apos sair da pagina.
- Capturas em build/validacao_ui/etapa3_*.png, incluindo celulares pequenos,
  fonte ampliada, tablet e tema escuro.
- Regressao automatizada dos fluxos existentes de carrinho, configuracao de
  pizza, destino do atendimento, sincronizacao e envio de impressao simulado.

## Publicacao e limites

Esta etapa altera o aplicativo Flutter. Nao inclui alteracoes na API nem
execucao de pedidos ou impressoes no restaurante real. A compilacao iOS sem
assinatura valida o codigo nativo, mas precisa ser assinada e instalada no
aparelho pelo fluxo de distribuicao existente. A impressora fisica e a leitura
de QR/NFC no equipamento precisam ser conferidas no ambiente de atendimento.
