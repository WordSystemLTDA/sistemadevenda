# Verificacao do modo Online — 24/11/2026

O aplicativo usa `https://bigchef.com.br/sistema/apis_restaurantes/api_restaurantes_venda/api45/`.
O modo Local testado pelo usuario foi preservado. Nenhum pedido, pagamento ou
comprovante real foi criado, reenviado ou excluido nesta verificacao.

## Achados

- A hospedagem respondeu HTTP 500, sem JSON, em `sincronizacao/estado.php`,
  `sincronizacao/recibo.php` e `sincronizacao/operacao.php`. As consultas usaram
  identidade invalida/corpo vazio, sem dados de clientes. A API42 respondeu
  erro JSON de validacao em operacao equivalente. A causa exata do erro 500
  depende dos arquivos e logs da hospedagem; falta de dependencia e uma
  possibilidade, nao uma causa confirmada remotamente.
- Os endpoints API45 `impressao/listar_pendentes.php` e
  `impressao/confirmar_recebimento.php` responderam erro JSON de validacao.
  Nenhuma reserva de lote nem confirmacao de impressao foi executada.
- O computador ainda usava API42 para recuperar a outbox Online e API41 para
  reconciliar o preparo Delivery. Ambos os caminhos foram alinhados a API45,
  mantendo o dominio e a empresa e sem mudar a API geral do computador.
- O PC `192.168.2.113` respondeu a descoberta UDP em `9992`, anunciou WebSocket
  `9990` e capacidades de modo Local. O celular conectado tambem estava Local.
  Para usar Online, os dois precisam estar Online na mesma empresa. Um canal
  Local nao pode assumir impressoes Online, mesmo usando o mesmo IP e porta.

## Correcoes e verificacao

- O carregamento das dependencias de sincronizacao da API45 passou a validar
  os arquivos diretos antes de `require`, necessario em PHP antigo, e as
  consultas de estado/recibo passaram a tratar a falha no bloco de erro JSON.
  O pedido permanece pendente no aparelho quando a API recusa o envio.
- O teste `sincronizacao_api45_publicacao_test.php` usa uma copia temporaria da
  API, conexao SQLite de teste e fixtures do schema oficial. Verifica rollback,
  reserva por executor, repeticao do mesmo ID, isolamento de empresa, ACK e
  publicacao incompleta. Nenhuma conexao de producao e carregada.
- Passaram os testes Flutter de canal Online, avisos de tela, pedidos pela
  rede, retomada, fila duravel e comprovantes de preparo/consumo/entregador nos
  modos Local/Online. O teste de widget Delivery passou a aguardar o intervalo
  da leitura agrupada ao fechar a pagina; nenhuma regra de producao do app foi
  alterada por esse ajuste do teste.

## Aplicacao

O pacote `Atualizacao_Online_API45_2026-11-24.zip`, em Downloads, contem PHP da
API45 e suas dependencias, sem `conexao.php`, credenciais ou SQL, e os fontes
Flutter do computador necessarios a correcao. O arquivo LEIA-ME diferencia os
dois destinos. Preservar a conexao da hospedagem; os fontes Flutter precisam
ser recompilados no Windows. O pacote nao e um instalador.

Nao houve publicacao na hospedagem nem atualizacao do executavel Windows.
Depois de aplicar os arquivos, validar novamente a API45 e, com PC/celular
Online na mesma empresa, testar um pedido e seus comprovantes. A impressao
fisica no modo Online ainda precisa dessa verificacao no ambiente do usuario.
