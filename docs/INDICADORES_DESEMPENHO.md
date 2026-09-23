# Indicadores de desempenho do atendimento

A tela de Indicadores foi redesenhada usando as cores da home como referência.
Nenhum componente, organização ou ação da home foi alterado.

## Conteúdo

- Visão da empresa e Meus atendimentos, com períodos e filtro por canal.
- Consumo registrado, ticket médio, atendimentos, finalizados e cancelamentos.
- Variação contra o período imediatamente anterior de igual duração, completo.
  O painel avisa que o período atual pode ainda estar em andamento.
- Metas de consumo/dia, atendimentos/dia e ticket médio, com progresso e valor
  restante. Zero ou campo vazio desativa a respectiva meta.
- Movimento por hora operacional (05h até 04h59), evolução diária alternando
  consumo e quantidade, participação por canal e situação dos atendimentos.
- Cinco produtos com maior consumo registrado, agrupados após aplicar o filtro
  de canal; quantidades fracionadas são preservadas.
- Orientações práticas e explicação das bases de cálculo na própria tela.

## Critérios e limites

Os indicadores continuam restritos aos níveis 0 e 1, conforme a permissão
existente. Não foi ampliado o acesso aos totais da empresa.

Meus atendimentos usa o operador registrado na abertura/lançamento, não o campo
legado id_vendedor, que recebe um valor fixo em alguns fluxos. Essa visão não
representa comissão nem todos os itens de atendimentos compartilhados.

Cobertura: mesas, comandas e balcão. Delivery e recorrentes não entram no cálculo.
Consumo inclui contas abertas e não representa recebimentos do caixa. Cancelados
são separados. Ticket médio é consumo/atendimentos válidos, não gasto por cliente.
Metas abrangem todos os canais da visão selecionada, mesmo ao filtrar um canal;
isso está indicado no cartão. Metas diárias são multiplicadas pelos dias do
período; a meta de ticket não é multiplicada.

A consulta continua atualizando a cada minuto quando a página está ativa, ao
retornar ao aplicativo e por atualização manual. O fallback offline existente
fica explicitamente identificado, isolado por servidor/empresa/usuário/escopo.
Não foi criado cache de catálogo/produtos para abertura de pedidos.

## Publicação

Atualizar o aplicativo e distribuir os arquivos de
`api_restaurantes_venda/api37/indicadores/`. A tabela nova
`indicadores_atendimento_metas` está definida integralmente no `schema.sql`
da API. Provisionar somente essa tabela em banco existente; não reimportar o
schema inteiro. Nenhuma requisição da aplicação executa DDL.

Sem a tabela, os indicadores continuam disponíveis e o cartão informa que metas
ainda não estão disponíveis. APIs antigas mantêm a visão da empresa, mas não
são aceitas como fonte de dados pessoais sem confirmação explícita do escopo.

O banco local configurado não estava acessível durante esta implementação.
Portanto a tabela não foi criada em banco real. Backend verificado em banco
isolado em memória, sem usar dados de clientes.

## Referências da pesquisa

A seleção de métricas se apoiou em documentação pública de fornecedores de
gestão de restaurantes, aplicando apenas medidas sustentadas pelos dados atuais:

- [Lightspeed — Staff Reports](https://k-series-support.lightspeedhq.com/hc/en-us/articles/18235356564507-Staff-Reports): desempenho por atendente e gasto médio.
- [Lightspeed — Staff Performance](https://k-series-support.lightspeedhq.com/hc/en-us/articles/40994945471515-Understanding-the-Staff-Performance-report): evolução horária/diária e seleção por usuário.
- [Toast — How to Measure and Increase Restaurant Sales](https://pos.toasttab.com/resources/how-to-increase-restaurant-sales): evolução das vendas, ticket e sugestões de complementos adequados ao cliente.

Não foram estimadas gorjetas, comissões, avaliações ou duração do atendimento
sem uma fonte confiável desses eventos.

## Validação

Testes em `test/modulos/indicadores/` cobrem cálculos, filtros, períodos,
cancelamento de consultas, escopo pessoal, cache, metas, estados de erro e
layout responsivo. O teste PHP independente está em
`apis_restaurantes/tests/indicadores_atendimento_test.php` e não carrega conexão
de produção. Capturas visuais são geradas em `build/validacao_ui/` com as flags
de teste `CAPTURAR_TELAS` e `FONTE_TESTE`.
