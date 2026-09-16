<?php
// API1 como primeiro argumento. Usa apenas PDO simulado, sem conexao com banco.
require_once $argv[1] . '/pedidos/edicao.php';

class ConsultaPedidoTeste extends PDOStatement
{
    private $banco;
    private $sql;
    private $linhas = [];
    private $parametros = [];
    public function __construct($banco, $sql) { $this->banco = $banco; $this->sql = $sql; }
    public function bindValue($param, $value, $type = PDO::PARAM_STR): bool {
        $this->parametros[$param] = $value; return true;
    }
    public function execute($params = null): bool {
        $this->linhas = $this->banco->executar($this->sql, $params ?? $this->parametros); return true;
    }
    public function fetchAll($mode = null, $class = null, $constructor = null, ...$args): array { return $this->linhas; }
}

class BancoPedidoTeste extends PDO
{
    public $comandos = [];
    public $commitado = false;
    public $desfeito = false;
    public $falharPacote = false;
    public $foraEmpresa = false;
    public $encerrado = false;
    public $transacao = false;
    public $recebido = 104;
    public $pedido = ['id' => '25', 'empresa' => '3', 'status' => 'Pendente',
        'tipo_de_entrega' => '1', 'valor_da_entrega' => '4', 'valor_total_pedido' => '104',
        'id_cliente' => '4', 'id_endereco' => '8', 'obs' => '', 'id_opcoes_carrossel' => '2'];
    public $venda = ['id' => '100', 'empresa' => '3', 'status' => 'Concluída',
        'cliente' => '4', 'id_endereco' => '0', 'obs' => '', 'tipo_de_entrega' => '3',
        'subtotal' => '95', 'desconto_percentual' => '10', 'desconto' => '5', 'acrescimo' => '10'];
    public $item = ['id' => '99', 'produto' => '101', 'quantidade' => '1',
        'valor' => '100', 'total' => '100', 'observacao' => '', 'valor_custo' => '10'];
    public function __construct() {}
    public function prepare($query, $options = []): PDOStatement { return new ConsultaPedidoTeste($this, $query); }
    public function beginTransaction(): bool { $this->transacao = true; return true; }
    public function commit(): bool { $this->transacao = false; $this->commitado = true; return true; }
    public function rollBack(): bool { $this->transacao = false; $this->desfeito = true; return true; }
    public function inTransaction(): bool { return $this->transacao; }
    public function executar($sql, $params): array {
        $this->comandos[] = [$sql, $params];
        if (strpos($sql, 'SELECT id FROM usuarios') === 0) return [['id' => '2']];
        if (strpos($sql, 'SELECT * FROM delivery') === 0) return $this->foraEmpresa ? [] : [$this->pedido];
        if (strpos($sql, 'SELECT * FROM vendas') === 0) return $this->foraEmpresa ? [] : [$this->venda];
        if (strpos($sql, 'SELECT tipo_de_impressao') === 0) return [['tipo_de_impressao' => $this->encerrado ? '3' : '1']];
        if (strpos($sql, 'SELECT * FROM itens_venda WHERE') === 0) return [$this->item];
        // Leitura dos pacotes antigos, vazios neste fixture; os novos usam os inserts reais.
        if (strpos($sql, 'SELECT itens_venda.*') === 0) return [];
        if (strpos($sql, 'SELECT id FROM ') === 0) return [['id' => $params[0]]];
        if (strpos($sql, 'SELECT valor_compra') === 0) return [['valor_compra' => '12', 'comissao' => '0']];
        if (strpos($sql, 'AS recebido') !== false) return [['recebido' => $this->recebido]];
        if (strpos($sql, 'AS custo') !== false) return [['custo' => '24']];
        if ($this->falharPacote && strpos($sql, 'INSERT INTO itens_venda_pizza') === 0) throw new RuntimeException('Falha simulada no pacote');
        if (preg_match('/^(UPDATE|DELETE|INSERT|SELECT \* from itens_venda_adicionais)/', $sql)) return [];
        throw new RuntimeException('SQL sem fixture: ' . $sql);
    }
}

function conferir($ok, $mensagem) { if (!$ok) throw new RuntimeException($mensagem); }
function entradaPedido($pdo, $tipo = 'Delivery') {
    return ['empresa' => '3', 'id_usuario' => '2', 'tipo' => $tipo, 'id' => '25', 'acao' => 'produto',
        'original' => ['iditensvenda' => '99', 'versaoEdicao' => pedidoVersaoItem($pdo->item, [])],
        'produto' => ['id' => '102', 'iditensvenda' => '99', 'valorVenda' => '85.00', 'quantidade' => 2,
            'observacao' => "Sem cebola e d'agua", 'opcoesPacotesListaFinal' => [
                ['id' => 9, 'dados' => [['id' => '2', 'valor' => '60']]],
                ['id' => 10, 'dados' => [['id' => '102', 'valor' => '30', 'estaSelecionado' => false],
                    ['id' => '103', 'valor' => '30', 'estaSelecionado' => false]]],
                ['id' => 6, 'dados' => [['id' => '4', 'valor' => '12']]],
                ['id' => 7, 'dados' => [['id' => '5', 'valor' => '13', 'quantidade' => 1]]],
            ]]];
}

function rejeitarPedido($pdo, $dados) {
    try { editarPedidoVenda($pdo, $dados, ''); }
    catch (Throwable $e) {
        conferir(!$pdo->commitado, 'Nao pode confirmar transacao em erro');
        return $e->getMessage();
    }
    throw new RuntimeException('Operacao invalida foi aceita');
}

foreach (['Delivery', 'Balcão'] as $tipo) {
    $pdo = new BancoPedidoTeste();
    $dados = entradaPedido($pdo, $tipo);
    $res = editarPedidoVenda($pdo, $dados, '');
    conferir($pdo->commitado, 'Edicao nao confirmada');
    conferir($res['total'] == ($tipo === 'Delivery' ? 174 : 158), 'Total com taxa/desconto percentual incorreto');
    conferir($res['recebido'] == 104, 'Pagamento foi modificado');
    $insertsPizza = array_filter($pdo->comandos, function ($c) { return strpos($c[0], 'INSERT INTO itens_venda_pizza') === 0; });
    conferir(count($insertsPizza) === 2, 'Sabores nao foram preservados');
    $atualizacao = array_values(array_filter($pdo->comandos, function ($c) { return strpos($c[0], 'UPDATE itens_venda SET produto') === 0; }))[0];
    conferir($atualizacao[1][0] === '102', 'Mudanca de sabor principal rejeitada');
    conferir($atualizacao[1][3] == 170, 'Total deve multiplicar a quantidade apenas uma vez');
    conferir($atualizacao[1][4] === "Sem cebola e d'agua", 'Observacao corrompida');
    foreach ($pdo->comandos as [$sql, $params]) {
        conferir(!preg_match('/^(UPDATE|INSERT INTO|DELETE FROM) (movimentacoes|contas_receber)/', $sql), 'Pagamento ou conta alterado implicitamente');
    }
    echo "OK: $tipo, sabores, bordas, adicionais, quantidade, taxa, descontos e pagamentos\n";
}

$pdo = new BancoPedidoTeste();
$dados = entradaPedido($pdo);
$dados['original']['versaoEdicao'] = 'antiga';
conferir(strpos(rejeitarPedido($pdo, $dados), 'alterado') !== false, 'Versao antiga nao detectada');
conferir($pdo->desfeito, 'Conflito deve desfazer transacao');
$pdo = new BancoPedidoTeste(); $pdo->falharPacote = true;
rejeitarPedido($pdo, entradaPedido($pdo));
conferir($pdo->desfeito, 'Pacote incompleto deve desfazer item e totais');
echo "OK: concorrencia e rollback de item/opcoes/totais\n";

foreach (['foraEmpresa', 'encerrado', 'fiscal', 'cancelado'] as $caso) {
    $pdo = new BancoPedidoTeste();
    if ($caso === 'fiscal') $pdo->venda['status_sefaz'] = '100';
    elseif ($caso === 'cancelado') $pdo->pedido['status'] = 'Cancelado';
    else $pdo->$caso = true;
    rejeitarPedido($pdo, entradaPedido($pdo));
}
echo "OK: empresa, fiscal, entrega encerrada e cancelamento protegidos\n";

$pdo = new BancoPedidoTeste();
$dados = entradaPedido($pdo);
$dados['produto']['valorVenda'] = '70'; $dados['produto']['quantidade'] = 1;
$res = editarPedidoVenda($pdo, $dados, '');
conferir($res['total'] == 74 && $res['diferenca'] == -30, 'Diferenca a devolver incorreta');
$dados = ['subtotal' => '85', 'desconto_percentual' => '10'];
conferir(pedidoTotaisEditados($dados, false, 10000, 10001, 0)['total'] === 8501, 'Centavos perdidos');
conferir(pedidoTotaisEditados(['valor_total_pedido' => '104', 'valor_da_entrega' => '4', 'tipo_de_entrega' => '1'], true, 10000, 10000, 0)['total'] === 10000, 'Taxa duplicada ou nao removida');
echo "OK: diferenca a devolver, centavos e troca de modalidade\n";

$pdo = new BancoPedidoTeste();
$res = editarPedidoVenda($pdo, ['empresa' => '3', 'id_usuario' => '2', 'tipo' => 'Delivery', 'id' => '25', 'acao' => 'pedido',
    'clienteOriginal' => '4', 'tipoEntregaOriginal' => '1', 'enderecoOriginal' => '8', 'observacaoOriginal' => '', 'taxaOriginal' => '4',
    'cliente' => '4', 'tipoentrega' => '2', 'endereco' => '0', 'taxa' => '0', 'observacao' => 'Retirada'], '');
conferir($res['total'] == 100 && $res['recebido'] == 104, 'Edicao de dados nao preservou valores');
echo "OK: edicao de pedido sem criar outra venda\n";

foreach (['media', 'maior'] as $modelo) {
    $bordas = [['valor' => '6', 'valorOriginal' => '12', 'somenteMetadeBorda' => true],
        ['valor' => '6', 'valorOriginal' => '12', 'somenteMetadeBorda' => true]];
    conferir(pedidoBordasVendidas($bordas, $modelo)[0]['somenteMetadeBorda'] === false, 'Duas bordas rateadas nao sao meia borda');
    $bordas[0]['valor'] = '3'; $bordas[1]['valor'] = '3';
    conferir(pedidoBordasVendidas($bordas, $modelo)[0]['somenteMetadeBorda'] === true, 'Meia borda com dois sabores deve ser preservada');
}
echo "OK: bordas rateadas e meia borda sem alterar valores\n";
