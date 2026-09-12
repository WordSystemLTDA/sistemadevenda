# Pedidos offline do garcom

## Escopo implementado

- Carrinhos de mesas/comandas e de itens recorrentes usam SQLite no aparelho.
- Produtos, tamanhos, sabores, bordas, adicionais, retiradas, observacoes e quantidades
  selecionados ficam no mesmo registro duravel da operacao e dos comprovantes.
- Finalizar grava a operacao e limpa somente aquele carrinho na mesma transacao.
  Falha de armazenamento nao confirma a finalizacao nem apaga o carrinho.
- O catalogo e as consultas previamente sincronizadas podem ser usados sem o servidor.
  A primeira entrada e a primeira preparacao dos dados precisam de conexao.
- Uma sessao ja autenticada pode ser retomada offline no mesmo servidor/empresa/usuario.
  Rejeicao de autenticacao pelo servidor nao e tratada como falta de rede.
- Abertura/edicao cadastral de atendimentos, pagamentos, fechamento, exclusoes e
  cadastros continuam sendo operacoes online. Nao ha reserva offline de uma mesa livre.
  Delivery/balcao nao usam a nova fila de lancamento de produtos.

## Seguranca e sincronizacao

Cada operacao recebe um identificador aleatorio persistente. A API grava o recibo
em `garcom_operacoes` na mesma transacao dos itens e complementos. Repetir o
identificador com o mesmo conteudo recupera o recibo anterior; nao insere novamente.
Um identificador com conteudo diferente e recusado.

O envio informa o ID real de `comandas_pedidos` e uma versao calculada com sua
identidade, data/hora de abertura e hash. A API bloqueia o registro para atualizar,
confere empresa, mesa/comanda, status Andamento e a ausencia de outro atendimento
ativo no recurso. Um pedido antigo nunca e redirecionado para a comanda nova.

Atendimento encerrado, transferido ou produto/opcao removidos geram conflito.
Os dados ficam no aparelho, sem impressao automatica. A tela de pendencias permite
conferir e arquivar explicitamente; arquivar nao apaga o registro nem relanca os itens.
Rascunhos de carrinhos bloqueados/encerrados tambem ficam disponiveis nessa tela.
Antes de fechar um atendimento pelo app, seus pedidos pendentes devem ser resolvidos.

O transporte verifica o IP da API, nao exige internet publica. Ha retomada periodica
(15 segundos enquanto o processo executa), ao mudar a rede, ao reconectar o socket e
ao retornar ao app. Consultas usam a ultima copia valida com atualizacao em segundo
plano; o catalogo completo e revisto em ate dois minutos ou apos aviso de alteracao.
Imagens ainda nao visitadas podem exibir o placeholder sem rede.

Filas/cache sao separados por servidor/empresa/usuario. Sair da conta nao apaga pedidos
pendentes; entrar novamente na conta original permite retoma-los. Nao limpar os dados
do aplicativo, desinstalar ou restaurar seu banco a uma copia antiga com pedidos pendentes.

## Impressao

Comprovantes somente entram na fila de impressao depois do commit confirmado pela API.
Usam o destino e o ID de requisicao originais. O socket consulta comprovantes sem ACK
antes de reenviar e exige o protocolo de impressao 2 ja existente no servidor desktop.
Confirmacoes ficam registradas no SQLite para impedir recriacao apos reinicio.

O app diferencia pendencia de pedido de pendencia de impressao. Uma impressora fisica
sem papel ou sem energia ainda exige intervencao; ACK nao garante papel entregue.
Nao enviar manualmente o mesmo pedido pela bancada sem antes conferir sua pendencia.

## Tela apagada

O app nao desconecta intencionalmente o socket ao ficar inativo. No iOS, cada envio
pede uma extensao limitada com `beginBackgroundTask`, encerrada no termino ou na
expiracao. Isso nao mantem o processo vivo indefinidamente. iOS e Android podem
suspender ou encerrar aplicativos; a fila retoma quando o processo volta a executar.
Nao existe garantia de sincronizacao imediata com o aparelho suspenso/desligado.

Referencia: [execucao em segundo plano no iOS](https://developer.apple.com/documentation/uikit/extending-your-app-s-background-execution-time).

## Implantacao coordenada

1. Fazer backup e provisionar **somente a estrutura nova `garcom_operacoes`** definida
   no `schema.sql` da API, usando o processo controlado de atualizacao do servidor.
   Nao executar o schema completo sobre um banco existente. Nenhum endpoint faz DDL.
2. Publicar `sincronizacao/{estado,operacao,operacoes}.php` e os arquivos alterados:
   `comandas/inserir_produtos.php`, `mesas/inserir_produtos.php`,
   `funcoes/sabores/inserir.php`, `cardapio/listar_por_id_comanda.php` e
   `categorias/listar.php`, todos em `api_restaurantes_venda/api1/`.
3. Se a conexao usar `api6` (URL online do aplicativo), disponibilizar o mesmo contrato
   nessa versao. Essa arvore nao esta presente neste checkout e nao foi publicada.
4. Manter o servidor desktop com recibos/confirmacoes duraveis do protocolo de impressao 2.
5. Instalar o app atualizado, entrar conectado e aguardar a preparacao do catalogo.
   Um servidor sem o novo contrato nao recebe lancamentos pela fila.
6. Homologar no aparelho e impressora reais antes do atendimento em producao.

Nao foram alterados dados ou provisionadas tabelas no banco de producao nesta tarefa.

## Verificacao

`flutter test` cobre os fluxos existentes, SQLite, recuperacao apos fechar/reabrir o
banco, resposta perdida, conflitos, separacao de contas, erro de disco e layouts.

`test/essencial/sincronizacao/servidor_test.php` exige uma instancia MariaDB descartavel
em `/private/tmp/garcom-mariadb-test/`, socket exclusivo e o schema canonico provisionado.
Recusa outro datadir. Ele insere fixtures sinteticas e valida transacao, rollback de
complementos, concorrencia, mesa/comanda e resposta repetida apos fechamento.

Homologacao manual obrigatoria: desligar Wi-Fi apos carregar o atendimento; montar
pizza completa e finalizar; reiniciar o app; reconectar; conferir um unico lancamento
e comprovante. Repetir encerrando/reabrindo a comanda pela bancada antes da reconexao:
o pedido antigo deve ficar em conflito, sem itens nem impressao na nova comanda.
