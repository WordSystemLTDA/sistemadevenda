# Comandas e mesas sem repeticao

Correcao de 09/10/2026 para o aplicativo `sistemadevenda` e a API41.

## Causa e comportamento

As respostas salvas do simulador continham cadastros com IDs diferentes e o
mesmo nome. A lista tinha 15 comandas para 11 nomes e 11 mesas para 10 nomes.

A listagem agrupa nomes iguais, ignorando espacos repetidos e maiusculas.
Prioriza a entrada com conta aberta; entre livres, conserva o cadastro ativo
com historico e depois o menor ID. IDs, codigos, valores, historico e pedidos
da entrada escolhida permanecem intactos. Contas abertas distintas continuam
acessiveis, mesmo quando seus cadastros possuem o mesmo nome.

O aplicativo aplica a regra depois de projetar aberturas locais. Assim, uma
abertura pendente num ID antigo continua ocupada e vinculada a esse ID, tanto
com internet quanto usando o cache offline. A resposta bruta fica preservada
no armazenamento; nao e necessario limpar o celular.

Na API41, listagens operacionais e de cadastro usam a mesma regra. Cadastro e
renomeacao recusam nomes repetidos na mesma empresa, com transacao para
serializar essas alteracoes. A edicao de codigos de cadastros antigos continua
permitida. Nao ha exclusao de cadastros, migracao, DDL nem alteracao de pedidos.

## Atualizacao

1. Recompilar/atualizar `sistemadevenda` (ou recarregar a sessao Flutter em uso).
2. Publicar na raiz da API41 o conteudo de
   `apis_restaurantes/build/comandas_mesas_sem_repeticao_api41_20261009.zip`.
   O pacote contem o novo helper `funcoes/recursos_atendimento.php` e os oito
   endpoints de listagem, cadastro e edicao em `comandas/` e `mesas/`.
   Nao inclui `conexao.php`, credenciais, testes ou schema.

## Verificacao

- 12 testes focados: nomes repetidos, IDs e valores preservados, duas contas
  distintas, fechamento, cache Online/offline e abertura local no ID duplicado.
- 65 testes existentes de sincronizacao passaram, incluindo Mesa/Comanda,
  retornos da conexao, pagamentos e fila de impressao.
- 28 verificacoes PHP usam os endpoints reais com fixture SQLite derivada do
  schema oficial, sem conexao com o banco da empresa.
- A projecao das respostas reais salvas do simulador resultou em 11 comandas
  livres e 10 mesas (1 ocupada e 9 livres), sem apagar dados do aparelho.

A hospedagem Online nao foi alterada neste ambiente; a prevencao de novos
cadastros repetidos no servidor depende da publicacao dos arquivos da API41.
