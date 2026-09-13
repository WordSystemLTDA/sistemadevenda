# Transferencias de mesas e comandas

## Uso

- Segurar um card ocupado e soltar sobre outro abre a conferencia, sem mover pedidos imediatamente.
- O menu de cada card tem **Transferir / Juntar** e **Historico de transferencias**. A busca de destino permite escolher recursos fora da parte visivel da lista.
- Destino ocupado: junta os itens no atendimento de destino. Destino livre: cria um novo atendimento, preserva cliente/observacao da origem e move os itens.
- A origem fica livre somente depois da confirmacao transacional do servidor. O registro anterior permanece com status `Transferida`.
- Se faltar a resposta, entrar novamente em **Transferir / Juntar**, em qualquer card, permite verificar a operacao pendente, inclusive depois de fechar o aplicativo.

## Seguranca e limites

- Requer conexao com o servidor. Nao enfileira uma uniao offline baseada apenas no numero da mesa/comanda.
- Revalida identidade, ocupacao, itens e valores dos dois atendimentos entre conferencia e confirmacao.
- Bloqueia rascunhos locais de produtos e operacoes/impressao pendentes destes atendimentos. Nao descarta esses dados.
- Requisicoes repetidas usam o mesmo identificador duravel. A consulta do recibo recupera uma transferencia ja confirmada sem executa-la de novo.
- Mesa transfere para mesa; comanda para comanda. Mesa com comanda vinculada deve ser tratada pela lista de comandas. Contas em fechamento, pagas ou com ajustes financeiros precisam de conferencia no caixa.
- Preserva IDs de itens, complementos, observacoes e estados de preparo. Nao solicita reimpressao dos pedidos; o garcom deve avisar a cozinha sobre o novo destino de entrega.
- Pedidos atrasados para a origem transferida ficam sujeitos a conferencia, nunca sao redirecionados automaticamente para o novo ocupante.
- O historico registra usuario, horario, recursos, atendimentos, IDs dos itens, valores anteriores/final e observacao da origem. A consulta usa paginas de 50 registros.

## Publicacao obrigatoria

Dois repositorios mudaram: o aplicativo e `sistema/apis_restaurantes`.

1. Publicar a versao revisada da API pelo Git no servidor usado pelo aplicativo.
2. Provisionar separadamente a tabela `garcom_transferencias`, cuja definicao completa esta somente no `schema.sql` da API. Nao importar o schema inteiro por cima do banco existente. Manter tambem `garcom_operacoes`, ja usado pela sincronizacao.
3. Distribuir a nova compilacao do aplicativo. As rotas novas estao em `api_restaurantes_venda/api1/transferencias/`; o executor e `sincronizacao/operacao.php`.
4. O modo Online usa `api6` na hospedagem: exige publicar os mesmos contratos nessa versao antes de habilitar a funcionalidade. Este workspace contem a implementacao `api1` local.

Nao ha criacao automatica de tabela em requisicoes. Sem a API/schema atualizados, o aplicativo mostra indisponibilidade e nao chama a transferencia legada do caixa.

## Validacao

- Flutter: `flutter test --no-pub --no-test-assets --concurrency=1`.
- Testes novos de interface/servico: `test/modulos/transferencias/transferencias_test.dart`.
- MariaDB isolado: `php -n test/modulos/transferencias/servidor_transferencias_test.php <repositorio-da-api>`.
- O teste PHP recusa qualquer instancia cujo `@@datadir` nao seja `/private/tmp/garcom-mariadb-test/`. Nao utiliza a conexao da empresa nem impressoras reais.
- O banco isolado utilizado nesta validacao foi encerrado e compactado em `/private/tmp/garcom-mariadb-test-validado.tgz` para liberar espaco.

Validacao no restaurante ainda necessaria: instalacao da nova compilacao, publicacao/provisionamento, dois aparelhos/caixa na mesma rede e conferencia de entrega na cozinha. Nenhuma venda real ou impressao fisica foi executada pelos testes.
