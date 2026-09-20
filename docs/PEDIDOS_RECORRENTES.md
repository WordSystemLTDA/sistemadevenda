# Pedidos recorrentes

O Inicio mostra **Recorrentes** no topo e nos atalhos quando
`config_bigchef.cliente_com_pedidos_decorrentes` estiver como `Sim`.

O botao + abre Novo Delivery com dias da semana, horario livre/fixo/intervalo
e entrega ou retirada. Cliente cadastrado e obrigatorio para ambos. O primeiro
pedido e para hoje; os proximos aparecem na agenda dos dias selecionados.
Os produtos sao escolhidos no cardapio existente. Revisar e Finalizar abre a
venda diaria preenchida, sem duplicar uma ocorrencia ja aberta. Pagamento e
impressao continuam no fluxo existente de venda. A agenda permite pausar o
cadastro, pular um dia ou retoma-lo, pesquisar e consultar sete dias.

Modelo, servico, provedor, agenda e formulario estao em
`lib/src/modulos/recorrentes`. Este recurso e distinto de `itens_recorrentes`,
que ja existia para itens de mesas/comandas.

Fontes PHP locais: `api_restaurantes_venda/api1/recorrentes`,
`api_restaurantes_venda/api1/config_bigchef/listar.php` e `pedidos_recorrentes/`
na raiz da API. Os wrappers de criacao/geracao usam o helper existente de
numeracao em `api_desktop/1.0.01/funcoes/pedidos/sequencia_operacional.php`.
No ambiente online, publicar as entradas do app em `api6`, conservando os
helpers compartilhados. `api6` nao tem copia local neste workspace.

As tabelas novas `pedidos_recorrentes` e `pedidos_recorrentes_dias` estao apenas
no schema oficial `C:/xampp/htdocs/sistema/apis_restaurantes/schema.sql` e
precisam de provisionamento separado. Nenhuma requisicao executa DDL.
O banco vivo, o servidor instalado e a API online nao foram alterados.

Regras completas, contrato e verificacoes:
`C:/Projetos/sistemarestaurante/docs/PEDIDOS_RECORRENTES.md`.
Teste local: `flutter test test/modulos/recorrentes/recorrentes_test.dart`.
