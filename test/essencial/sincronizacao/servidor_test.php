<?php
// Executar somente contra a instancia descartavel provisionada com schema.sql.
require_once $argv[1] . '/api_restaurantes_venda/api1/sincronizacao/operacoes.php';

class PdoTeste extends PDO {
    public $falharNoSegundo = false;
    private $insercoes = 0;
    public function prepare($sql, $options = []) {
        if ($this->falharNoSegundo && stripos($sql, 'INSERT INTO itens_venda set') !== false) {
            if (++$this->insercoes === 2) throw new RuntimeException('Queda simulada no segundo produto');
        }
        return parent::prepare($sql, $options);
    }
}

function conectarTeste() {
    $socket = '/private/tmp/garcom-mariadb-test.sock';
    $pdo = new PdoTeste("mysql:unix_socket=$socket;dbname=eadsagestart;charset=utf8mb4", 'root', '',
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    if (strpos($pdo->query('SELECT @@datadir')->fetchColumn(), '/private/tmp/garcom-mariadb-test/') !== 0) {
        throw new RuntimeException('Banco nao autorizado para testes');
    }
    $pdo->exec("SET SESSION sql_mode = ''");
    return $pdo;
}

function verificar($condicao, $mensagem) {
    if (!$condicao) throw new RuntimeException($mensagem);
}

function fixture($pdo, $tabela, $valores) {
    foreach ($pdo->query("SHOW COLUMNS FROM `$tabela`")->fetchAll(PDO::FETCH_ASSOC) as $coluna) {
        $nome = $coluna['Field'];
        if (array_key_exists($nome, $valores) || $coluna['Null'] === 'YES' ||
            $coluna['Default'] !== null || strpos($coluna['Extra'], 'auto_increment') !== false) continue;
        $tipo = $coluna['Type'];
        $valores[$nome] = preg_match('/int|decimal|double|float/', $tipo) ? 0 :
            (strpos($tipo, 'date') !== false ? '2026-09-12' :
            (strpos($tipo, 'time') !== false ? '12:00:00' : ''));
    }
    $campos = implode('`,`', array_keys($valores));
    $marcadores = implode(',', array_fill(0, count($valores), '?'));
    $pdo->prepare("INSERT INTO `$tabela` (`$campos`) VALUES ($marcadores)")->execute(array_values($valores));
}

function esperarConflito($pdo, $entrada) {
    try { garcomOperacao($pdo, $entrada); }
    catch (ConflitoGarcom $e) { return; }
    throw new RuntimeException('Operacao incorreta foi aceita');
}

$pdo = conectarTeste();
foreach (['garcom_operacoes', 'itens_venda_sabores_de_bordas', 'itens_venda_pizza',
    'itens_venda', 'comandas_pedidos', 'usuarios', 'produtos', 'permissoes_empresa', 'empresas', 'sabores_de_bordas'] as $tabela) {
    $pdo->exec("DELETE FROM `$tabela`");
}
fixture($pdo, 'usuarios', ['id' => 1, 'empresa' => 32, 'ativo' => 'Sim']);
fixture($pdo, 'empresas', ['id' => 32]);
fixture($pdo, 'permissoes_empresa', ['empresa' => 32]);
fixture($pdo, 'sabores_de_bordas', ['id' => 1, 'empresa' => 32]);
fixture($pdo, 'sabores_de_bordas', ['id' => 2, 'empresa' => 32]);
fixture($pdo, 'produtos', ['id' => 5, 'empresa' => 32, 'nome' => 'Pizza', 'ativo' => 'Sim',
    'ncm' => 0, 'cfop' => 0, 'csosn' => 0, 'valor_venda' => 60, 'valor_compra' => 10]);
fixture($pdo, 'comandas_pedidos', ['id' => 104, 'empresa' => 32, 'id_comanda' => 4,
    'id_mesa' => 0, 'status' => 'Andamento', 'data_abertura' => '2026-09-12',
    'hora_abertura' => '12:00:00', 'hash' => 'sessao-original']);
$atendimento = $pdo->query('SELECT * FROM comandas_pedidos WHERE id = 104')->fetch(PDO::FETCH_ASSOC);
$produto = ['id' => '5', 'quantidade' => 2, 'valorVenda' => 72,
    'observacao' => "Sem cebola e borda d'agua", 'opcoesPacotesListaFinal' => [
        ['id' => 10, 'dados' => [['id' => '5', 'valor' => 60]]],
        ['id' => 6, 'dados' => [['id' => '1', 'valor' => 6], ['id' => '2', 'valor' => 6]]],
    ]];
$entrada = ['empresa' => '32', 'id_usuario' => '1', 'id_operacao' => str_repeat('a', 48),
    'acao' => 'produtos', 'dados' => ['id_comanda_pedido' => '104',
        'versao_atendimento' => garcomVersao($atendimento), 'tipo' => 'comanda',
        'id_comanda' => '4', 'id_mesa' => '0', 'id_cliente' => '0', 'produtos' => [$produto]]];
$resposta = garcomOperacao($pdo, $entrada);
verificar($resposta['sucesso'] === true, 'Falha ao inserir');
verificar($pdo->query('SELECT COUNT(*) FROM itens_venda')->fetchColumn() == 1, 'Quantidade de itens');
verificar($pdo->query('SELECT COUNT(*) FROM itens_venda_pizza')->fetchColumn() == 1, 'Sabores nao inseridos');
verificar($pdo->query('SELECT SUM(valor) FROM itens_venda_sabores_de_bordas')->fetchColumn() == 12, 'Bordas incorretas');
verificar($pdo->query('SELECT observacao FROM itens_venda LIMIT 1')->fetchColumn() === $produto['observacao'], 'Observacao perdeu aspas');
echo "OK: pedido, pizza, bordas, quantidade e observacao atomicos\n";

verificar(garcomOperacao($pdo, $entrada) === $resposta, 'Recibo diferente no reenvio');
verificar($pdo->query('SELECT COUNT(*) FROM itens_venda')->fetchColumn() == 1, 'Pedido duplicado');
echo "OK: reenvio idempotente apos perda de resposta\n";

$outro = $entrada;
$outro['dados']['produtos'][0]['quantidade'] = 3;
esperarConflito($pdo, $outro);
echo "OK: mesmo identificador com conteudo diferente recusado\n";

$pdo->exec("UPDATE comandas_pedidos SET status = 'Finalizada' WHERE id = 104");
fixture($pdo, 'comandas_pedidos', ['id' => 105, 'empresa' => 32, 'id_comanda' => 4,
    'id_mesa' => 0, 'status' => 'Andamento', 'data_abertura' => '2026-09-12',
    'hora_abertura' => '13:00:00', 'hash' => 'nova-sessao']);
verificar(garcomOperacao($pdo, $entrada) === $resposta, 'Reenvio de pedido confirmado deve recuperar recibo mesmo apos fechamento');
$outro = $entrada;
$outro['id_operacao'] = str_repeat('b', 48);
esperarConflito($pdo, $outro);
verificar($pdo->query('SELECT COUNT(*) FROM itens_venda WHERE id_comanda_pedido = 105')->fetchColumn() == 0, 'Lancou na comanda reaberta');
echo "OK: comanda encerrada e reaberta nunca recebe o pedido antigo\n";

$pdo->exec("UPDATE comandas_pedidos SET status = 'Finalizada' WHERE id = 105");
$pdo->exec("UPDATE comandas_pedidos SET status = 'Andamento' WHERE id = 104");
$outro['dados']['versao_atendimento'] = 'versao-incorreta';
esperarConflito($pdo, $outro);
$outro['dados']['versao_atendimento'] = garcomVersao($atendimento);
$outro['dados']['id_comanda'] = '8';
esperarConflito($pdo, $outro);
echo "OK: versao e recurso divergentes recusados\n";

$outro = $entrada;
$outro['id_operacao'] = str_repeat('c', 48);
$outro['dados']['produtos'][] = $produto;
$pdo->falharNoSegundo = true;
try {
    garcomOperacao($pdo, $outro);
    throw new LogicException('Falha simulada nao ocorreu');
} catch (RuntimeException $e) {
    verificar(!($e instanceof LogicException), $e->getMessage());
}
$pdo->falharNoSegundo = false;
verificar($pdo->query('SELECT COUNT(*) FROM itens_venda')->fetchColumn() == 1, 'Rollback incompleto');
verificar($pdo->query('SELECT COUNT(*) FROM itens_venda_sabores_de_bordas')->fetchColumn() == 2, 'Pacotes nao revertidos');
verificar($pdo->query('SELECT COUNT(*) FROM garcom_operacoes')->fetchColumn() == 1, 'Recibo de pedido parcial');
echo "OK: falha no segundo produto reverte pedido, complementos e recibo\n";

// Dois processos usam conexoes independentes e o mesmo identificador.
$outro['id_operacao'] = str_repeat('d', 48);
$filho = pcntl_fork();
if ($filho === 0) {
    garcomOperacao(conectarTeste(), $outro);
    exit(0);
}
garcomOperacao(conectarTeste(), $outro);
pcntl_waitpid($filho, $status);
verificar(pcntl_wexitstatus($status) === 0, 'Processo concorrente falhou');
$pdo = conectarTeste();
verificar($pdo->query('SELECT COUNT(*) FROM itens_venda')->fetchColumn() == 3, 'Concorrencia duplicou itens');
echo "OK: requisicoes concorrentes gravam uma unica vez\n";

fixture($pdo, 'comandas_pedidos', ['id' => 106, 'empresa' => 32, 'id_comanda' => 0,
    'id_mesa' => 6, 'status' => 'Andamento', 'data_abertura' => '2026-09-12',
    'hora_abertura' => '14:00:00', 'hash' => 'mesa-original']);
$mesa = $pdo->query('SELECT * FROM comandas_pedidos WHERE id = 106')->fetch(PDO::FETCH_ASSOC);
$outro = $entrada;
$outro['id_operacao'] = str_repeat('e', 48);
$outro['dados']['id_comanda_pedido'] = '106';
$outro['dados']['id_comanda'] = '0';
$outro['dados']['id_mesa'] = '6';
$outro['dados']['tipo'] = 'mesa';
$outro['dados']['versao_atendimento'] = garcomVersao($mesa);
garcomOperacao($pdo, $outro);
garcomOperacao($pdo, $outro);
verificar($pdo->query('SELECT COUNT(*) FROM itens_venda WHERE id_comanda_pedido = 106')->fetchColumn() == 1, 'Pedido da mesa duplicado');
echo "OK: mesa usa a mesma transacao e recibo idempotente\n";
