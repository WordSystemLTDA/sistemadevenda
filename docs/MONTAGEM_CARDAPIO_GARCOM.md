# Montagem do cardapio no garcom

## Preco de Mais em 08/10/2026

A consulta Online da empresa 2 confirmou a Marmita P (23601) por R$ 20,00,
mas os ingredientes retornados pela API39 nao traziam valorAdicionalMais.
A consulta de vinculos da API desktop Online confirmou R$ 5,00 para Mais
no Arroz da categoria 4, quinta-feira. A montagem tinha permissoes completas,
por isso o app encerrava a complementacao sem consultar o preco faltante.
O caminho desktop tambem nao reconhecia API39.

ServicoProduto agora completa permissoes e preco ausentes. API39 Online usa
api_desktop_versao/1.1.87; Local e APIs antigas conservam api_desktop/1.0.01.
A consulta informa empresa, categoria e dia do ingrediente. Cada ingrediente
recebe sua propria tarifa, aceita os campos camelCase/snake_case e distingue
preco zero de campo ausente. Um zero informado nao e substituido pela consulta
auxiliar. CardProduto reutiliza a montagem do catalogo somente quando todos os
ingredientes possuem tarifa valida, incluindo zero; caso contrario aguarda os
detalhes completos antes de exibir as escolhas. Dados completos dispensam a
consulta adicional.

O calculo existente soma Mais ao valor unitario: 20 + 5 = 25. Normal remove
esse adicional; Mais por zero conserva o preco base. Carrinho, edicao e
snapshot de envio preservam o valor cobrado. Nao existe taxa fixa de R$ 5,00.
72 testes Flutter passaram, incluindo os exemplos 20 + 5, 45 + 2,75 e 20 + 0,
rotas Online/Local, valores distintos por ingrediente, reversao e carrinho.
O teste integrado abre o card da Marmita P com a resposta Online incompleta,
consulta a tarifa da empresa 2/categoria 4/quinta e confirma R$ 25,00 no carrinho.
Suites PHP confirmaram tarifa do banco, preservacao historica e rejeicao de
tarifa alterada. As consultas da hospedagem foram somente leitura.

Atualizar o app e publicar os helpers do pacote
build/correcoes/api39_montagem_preco_mais_20261008.zip para que listagem,
validacao e gravacao da API tambem usem a tarifa. O pacote contem o wrapper
da API39 e as rotinas canonicas de montagem para os caminhos desktop Local
e Online; nao inclui conexao.php, credenciais ou SQL. As fontes PHP dessas
rotinas ja estavam corretas no repositorio, mas a resposta da hospedagem
ainda omitia a tarifa. A publicacao na hospedagem nao foi executada aqui.

## Impressao compacta (02/10/2026)

O payload de preparo passa a enviar `Mais  - Bife`, `Sem   - Refogado` e
`Pouco - Feijao`, com acao e ingrediente juntos. Troca conserva destino e
quantidade; separado aparece como `- Embalar Separado`. Os campos estruturados
`montagemCardapio`, inclusive a tarifa salva, permanecem intactos. O texto e
exclusivo da impressao; nao modifica produto/carrinho, tela ou dados enviados
para gravar o pedido. Normal sem alteracao continua omitido.

O papel e gerado pelo `sistemarestaurante`, cujo formatador compartilhado
tambem foi atualizado para preparo, consumo e entregador. Atualizar o app e
as centrais de impressao juntos: uma central anterior que usa o JSON
estruturado ainda pode imprimir em duas linhas. Nao ha alteracao PHP/schema
nem mudanca nos IDs, filas, destinos ou confirmacoes da impressao.
Testes verificam texto, serializacao/reabertura, snapshot e fluxo de envio;
nenhuma impressora fisica foi acionada.

## Correcao de 17/09/2026

O produto Almoço Livre (id 436, codigo 151, empresa 32) possui
`id_categoria_cardapio = 3`. A consulta real ao servidor 192.168.2.109 mostrou
que a API desktop retornava Arroz, Carne de Panela e Feijao, mas a API do
garcom retornava apenas os adicionais Ovo e Bisteca. Reiniciar somente o
Flutter nao corrigia essa diferenca.

As alteracoes PHP estao no repositorio irmao
`sistema/apis_restaurantes/api_restaurantes_venda/api1/`. Elas incluem o vinculo
nas consultas de produtos e o grupo `id=12, tipo=8` nos pacotes, alem da
gravacao, leitura e substituicao dos ingredientes ao editar um pedido.
Esse grupo nao e uma observacao de produto.

`funcoes/cardapio.php` reutiliza as rotinas existentes em
`api_desktop/1.0.01/funcoes/cardapio/` para respeitar empresa, ingredientes
ativos e dia da semana. As tabelas e colunas existentes sao utilizadas.

O aplicativo atualiza consultas antigas que nao informavam o vinculo e
consulta os ingredientes atuais ao abrir um produto de cardapio. O cache
continua disponivel quando ha falha de conexao. Produtos sem montagem
continuam usando o cache imediato. Um produto vinculado com resposta
incompleta permite tentar novamente; um dia sem ingredientes exibe a
indisponibilidade na etapa de montagem.

## Publicacao

Publicar os PHP alterados no servidor que atende a URL configurada no app.
O pacote `build/atualizacao_cardapio_garcom.zip` contem os arquivos da API1
com caminhos relativos a raiz `sistema/apis_restaurantes`. Ele depende das
rotinas de montagem desktop ja instaladas, sem incluir configuracao de
conexao nem alteracoes de banco.

Depois da publicacao, a consulta abaixo deve informar
`idCategoriaCardapio: "3"` e incluir um grupo com `tipo: 8` e os tres
ingredientes habilitados para quinta-feira:

```text
http://192.168.2.109/sistema/apis_restaurantes/api_restaurantes_venda/api1/produtos/listar_por_id.php?id=436&empresa=32&id_usuario=0&id_tamanhos_pizza=0
```

O fluxo esperado e: produto, montagem (Normal selecionado), troca opcional
com retorno a montagem, adicionais, carrinho. Mais soma a tarifa cadastrada
para o ingrediente; adicionais mantem o preco cadastrado. O carrinho exibe
nomes e detalhes separados e o payload de impressao mantem todas as escolhas.

## Verificacao

```sh
flutter test --no-pub test/modulos/cardapio test/essencial/sincronizacao test/essencial/utils/impressao_preparo_test.dart
flutter analyze --no-pub
```

Na raiz do repositorio das APIs:

```sh
php tests/cardapio_garcom_test.php
php tests/cardapio_montagem_test.php
```

Os testes nao alteram pedidos reais nem enviam impressao fisica. O teste
Flutter usa o contrato do Almoço Livre em celular e tablet; o PHP executa
as consultas de ingredientes em SQLite em memoria e captura as insercoes
de montagem para verificar sua leitura posterior.
