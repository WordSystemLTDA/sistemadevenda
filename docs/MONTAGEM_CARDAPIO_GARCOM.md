# Montagem do cardapio no garcom

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
com retorno a montagem, adicionais, carrinho. Alteracoes e trocas nao
acrescentam valor; adicionais mantem o preco cadastrado. O carrinho exibe
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
