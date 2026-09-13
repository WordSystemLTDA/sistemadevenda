# Atendimento e visual: etapa 2

Data: 12/09/2026. Referencia: `Melhorias_Aplicativo_Garcom_Mesas_Comandas_Balcao.docx`.
Continua a etapa 1, que entregou os indicadores e correcoes de detalhes/fechamento.
Nao e uma reescrita nem a conclusao de todos os recursos opcionais do documento.

## Alteracoes implementadas

| Requisito | Evidencia e entrega |
| --- | --- |
| RF03: favoritos | Estrela em cada produto e filtro ao lado da busca. Preferencias pessoais do aparelho, separadas por servidor, empresa e usuario. |
| RF03: catalogo confiavel | Favoritos guardam somente IDs. Produtos, precos e montagens continuam vindo da consulta existente; nao sao congelados em uma segunda lista. O filtro inclui resultados alem da primeira pagina. |
| RF03/RT01: busca | Busca derivada do catalogo offline ignora acentos e caixa: `acai` encontra `Acai` com acento e `agua` encontra `Agua` com acento. Mantida a correspondencia exata de codigos com zeros/atalho. |
| UX01/UX03: produtos | Nome e preco legiveis, fotos cadastradas em miniaturas, sem a grande imagem generica repetida. Acoes de adicionar/personalizar e favoritar com area de 48 x 48. Precos com contraste nos temas claro e escuro. |
| UX02: tablet | Duas colunas a partir de 720 pontos quando o texto cabe; uma coluna em celular ou texto muito ampliado. Lista continua rolavel e carregada sob demanda. |
| RF03/RF05: montagens | Botao de personalizacao para pacote/kit e selecao de sabores para pizza. Nao pula bordas, adicionais, limites ou campos de valor livre. Favoritar nunca adiciona nem envia um produto. |
| RN02: valores apresentados | Menor valor real dos tamanhos como preco inicial, sem depender da ordem do cadastro. Faixa de valores dos tamanhos de pacotes, preco promocional e preco anterior. Formulas de cobranca e envio preservadas. |
| RF02/RF09: destino | Nome do atendimento no cabecalho do cardapio, recebido das rotas existentes, e no carrinho a partir da consulta validada do atendimento. Numero fisico nao substitui ID interno. |
| RF09/UX02: rascunho | Total dos novos itens junto do carrinho; identificacao de Novos itens na conferencia. Area inferior reservada, sem produtos passando atras dos botoes. |
| RF02/RT03: correcao | Entrada de mesa por codigo/QR no modo de abertura direta usava `TipoCardapio.comanda` e invertia o recurso. Agora usa Mesa, idMesa correto e o mesmo ID unico de atendimento retornado pela API. |

## Arquivos principais

- `lib/src/modulos/cardapio/provedores/favoritos_produtos.dart`: preferencias,
  serializacao de toques, isolamento, descarte e tratamento de falhas.
- `lib/src/modulos/cardapio/paginas/widgets/tab_custom.dart`: busca/filtro,
  lista responsiva, vazio, erro e atualizacao do catalogo.
- `lib/src/modulos/cardapio/paginas/widgets/card_produto.dart`: apresentacao e
  acoes; preservados os fluxos anteriores de selecao/adicao/personalizacao.
- `lib/src/modulos/cardapio/provedores/provedor_produtos.dart`: atualizacao de
  consulta completa sem voltar indevidamente a primeira pagina.
- `lib/src/essencial/utils/normalizar_busca.dart` e
  `lib/src/essencial/sincronizacao/cache_consultas.dart`: busca local sem acentos.
- `pagina_cardapio.dart`, `pagina_carrinho.dart` e chamadores de cardapio:
  destino e resumo da rodada, sem alterar IDs nem formato de pedidos.
- `pagina_mesas.dart` e `modal_digitar_codigo.dart`: correcao do tipo/recurso.

## Persistencia e compatibilidade

Chave de preferencia: `favoritos_produtos:v1:<escopo servidor/empresa/usuario>`.
Conteudo: lista de IDs, sem senhas, dados de clientes, precos ou montagens.
Toques sucessivos sao serializados; a interface confirma a estrela apos gravar.
Troca de usuario invalida retornos antigos. Troca conhecida de servidor recusa
gravacao no escopo anterior. Falha de preferencias tem mensagem e nova tentativa.

Nao ha migracao de banco, dependencia nova ou endpoint novo nesta etapa.
Nao houve alteracao nos contratos de venda, pagamentos, sincronizacao ou impressao.
O aplicativo atualizado utiliza as rotas de catalogo que ja existem na API.
Retornar a interface anterior nao exige apagar a fila local nem os favoritos.

Favoritos sao pessoais e locais, nao favoritos da loja publicados em todos os
aparelhos. A consulta usa o cache/servidor existente, inclusive a politica atual
de atualizacao; nao garante estoque em tempo real enquanto o aparelho esta offline.
Produto inativo recebido na lista fica bloqueado; produtos omitidos pela API nao
sao ressuscitados pelos favoritos. Estoque zero nao e interpretado como esgotado,
pois o cadastro atual nao estabelece essa regra para todos os tipos de produto.

O filtro usa a consulta completa existente da categoria, apenas quando ativado
ou pesquisado. Ainda e necessario medir essa consulta em catalogos grandes no
hardware real; nao foi declarado atendimento das metas de 5.000 produtos/300 ms.
Sinonimos e abreviacoes comerciais nao foram inventados: precisam de cadastro.

## Validacao

Novos testes em `test/modulos/cardapio/favoritos_produtos_test.dart`,
`catalogo_rapido_test.dart` e `destino_codigo_test.dart`.
Busca offline integrada em `test/essencial/sincronizacao/sincronizacao_test.dart`.
Mantidos testes de montagem, navegacao, carrinhos, reconexao e impressao.

Cenarios: persistencia, isolamento de usuarios/empresas/servidores, toques rapidos,
logout durante gravacao, preferencia corrompida, dispose durante leitura, favorito
apos a primeira pagina, filtro e busca juntos, falha com nova tentativa,
atualizacao de preco/inativacao, mesa e comanda com IDs fisicos/internos distintos.
Capturas em `build/validacao_ui/*etapa2*`: celular, tablet, texto ampliado e escuro.
Os dados exibidos nas capturas sao ficticios.

Executar `flutter test --no-pub --no-test-assets` para a regressao completa.
Os testes PHP existentes usam somente a base MariaDB descartavel e verificam
o diretorio antes de gravar. Nao executar esses testes no banco do restaurante.

## Pendencias do documento

| Prioridade | Trabalho que nao deve ser confundido com esta entrega |
| --- | --- |
| P0 | Homologacao fisica de impressoras, telefone e Wi-Fi; auditoria e evolucao da autenticacao legada, TLS e sessoes. |
| P1 | Revalidacao comercial de preco/disponibilidade alterados durante rascunho offline, com politica de divergencia aprovada pelo restaurante. |
| P1 | Producao por setor, pronto/entregue e entrega parcial com eventos reais do servidor. Impressora aceita nao significa comida pronta. |
| P1 | Transferencias, consumo por pessoa e divisao financeira integrados ao caixa com permissoes e concorrencia. |
| P1 | Identificacao de retirada e separacao dos estados de pagamento e preparo no balcao. |
| P2 | Chamados, QR hibrido, sugestoes configuraveis e novos indicadores baseados em eventos reais. |
| P3 | IA/voz com confirmacao humana, permissoes, controle de custos e protecao de dados. |

Consultar tambem `MELHORIAS_ATENDIMENTO_ETAPA_1.md` para o painel de indicadores,
regras dos numeros e dependencias da API. Nao foram contratados servicos externos,
alteradas regras fiscais nem simuladas confirmacoes de cozinha ou pagamento.

## Publicacao

Resultado desta entrega:

- 376 testes Flutter aprovados na rodada final completa (1 min 34 s).
- 17 cenarios de sincronizacao da API aprovados na base descartavel, incluindo
  concorrencia, reenvio, abertura offline, reutilizacao de recurso e pagamentos.
- Testes da API de indicadores aprovados: autorizacao/empresa, periodos e totais.
- Capturas finais verificadas em 393, 320 com texto ampliado e 820 pontos,
  incluindo tema escuro e duas colunas no tablet.
- Build iOS debug concluido em `build/ios/iphoneos/Runner.app`, sem assinatura
  e sem instalacao no telefone.
- `git diff --check` aprovado. Analise dos arquivos alterados sem erros;
  permanecem 10 avisos informativos de contexto assincrono no fluxo legado
  `pagina_comanda_desocupada.dart` (nesta etapa ele recebeu apenas o nome do destino).
- Nenhum pedido, pagamento ou trabalho de impressao criado no servidor real.
  A base MariaDB descartavel foi encerrada ao terminar.

Distribuir o aplicativo pelo fluxo habitual. Favoritos aparecem pela estrela do
produto e pelo filtro da busca; nenhum cadastro adicional e obrigatorio.
Validar em horario combinado: mesa correta, produto simples, pizza completa,
queda e retorno de rede, consulta do rascunho e impressao no equipamento real.
Nenhum teste automatizado equivale a garantia de zero falhas ou conexao permanente
com a tela apagada: iOS/Android podem suspender o aplicativo em segundo plano.
