<?php
// Executar somente contra a instancia descartavel provisionada com schema.sql.
require_once $argv[1] . '/api_restaurantes_venda/api37/sincronizacao/operacoes.php';
require_once $argv[1] . '/api_desktop/1.0.01/funcoes/pedidos/recebimento_transacional.php';
if (!function_exists('gerarHash')) {
    function gerarHash() { return bin2hex(random_bytes(20)); }
}

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
    'itens_venda', 'comandas_pedidos', 'comandas', 'mesa', 'usuarios', 'produtos', 'permissoes_empresa', 'empresas', 'sabores_de_bordas',
    'clientes', 'enderecos_clientes', 'opcoes_carrossel', 'delivery'] as $tabela) {
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
    'hora_abertura' => '12:00:00', 'hash' => 'sessao-original', 'data_fechamento' => null]);
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

fixture($pdo, 'comandas', ['id' => 20, 'empresa' => 32, 'nome' => '20', 'ativo' => 'Sim']);
fixture($pdo, 'mesa', ['id' => 20, 'empresa' => 32, 'nome' => '20', 'ativo' => 'Sim']);
$nova = ['empresa' => '32', 'id_usuario' => '1', 'id_operacao' => str_repeat('f', 48),
    'acao' => 'abertura', 'dados' => ['tipo' => 'comanda', 'id_comanda' => '20',
    'id_mesa' => '20', 'id_cliente' => '0', 'obs' => "Cliente d'Agua",
    'recursos' => [
        'comanda:20' => garcomRecurso($pdo, '32', 'comanda', '20')['versao'],
        'mesa:20' => garcomRecurso($pdo, '32', 'mesa', '20')['versao']]]];
$abertura = garcomOperacao($pdo, $nova);
verificar(garcomOperacao($pdo, $nova) === $abertura, 'Abertura repetida nao recuperou recibo');
verificar($pdo->query("SELECT COUNT(*) FROM comandas_pedidos WHERE id_comanda = 20")->fetchColumn() == 1, 'Abertura duplicada');
$dependente = $entrada;
$dependente['id_operacao'] = str_repeat('1', 48);
$dependente['dados']['id_comanda_pedido'] = 'local:' . $nova['id_operacao'];
$dependente['dados']['id_abertura'] = $nova['id_operacao'];
$dependente['dados']['id_comanda'] = '20';
$dependente['dados']['id_mesa'] = '20';
unset($dependente['dados']['versao_atendimento']);
$reciboItens = garcomOperacao($pdo, $dependente);
verificar($reciboItens['id_comanda_pedido'] === $abertura['id_comanda_pedido'], 'Itens foram para outra abertura');
verificar($reciboItens['numeroPedido'] === $abertura['numeroPedido'], 'Numero de impressao incorreto');
echo "OK: abertura offline e produtos dependentes recebem identidade e numero definitivos, sem duplicar\n";

$pdo->prepare("UPDATE comandas_pedidos SET status = 'Finalizada' WHERE id = ?")->execute([$abertura['id_comanda_pedido']]);
verificar(garcomOperacao($pdo, $nova) === $abertura, 'Reenvio reabriu atendimento encerrado');
verificar(garcomOperacao($pdo, $dependente) === $reciboItens, 'Reenvio de item confirmado falhou apos fechamento');
$dependente['id_operacao'] = str_repeat('2', 48);
esperarConflito($pdo, $dependente);
$nova['id_operacao'] = str_repeat('3', 48);
esperarConflito($pdo, $nova);
echo "OK: recurso usado e liberado novamente invalida abertura antiga; produtos nao reabrem comanda\n";

$nova['dados']['recursos'] = [
    'comanda:20' => garcomRecurso($pdo, '32', 'comanda', '20')['versao'],
    'mesa:20' => garcomRecurso($pdo, '32', 'mesa', '20')['versao']];
$outraAbertura = garcomOperacao($pdo, $nova);
esperarConflito($pdo, $dependente);
verificar($pdo->query('SELECT COUNT(*) FROM itens_venda WHERE id_comanda_pedido = ' . (int)$outraAbertura['id_comanda_pedido'])->fetchColumn() == 0,
    'Pedido atrasado foi para atendimento novo');
echo "OK: comanda reutilizada nao recebe produtos do atendimento local anterior\n";

fixture($pdo, 'mesa', ['id' => 21, 'empresa' => 32, 'nome' => '21', 'ativo' => 'Sim']);
$novaMesa = ['empresa' => '32', 'id_usuario' => '1', 'id_operacao' => str_repeat('4', 48),
    'acao' => 'abertura', 'dados' => ['tipo' => 'mesa', 'id_mesa' => '21', 'id_comanda' => '0',
    'id_cliente' => '0', 'recursos' => ['mesa:21' => garcomRecurso($pdo, '32', 'mesa', '21')['versao']]]];
$primeira = garcomOperacao($pdo, $novaMesa);
$novaMesa['id_operacao'] = str_repeat('5', 48);
esperarConflito($pdo, $novaMesa);
verificar($pdo->query('SELECT COUNT(*) FROM comandas_pedidos WHERE id_mesa = 21')->fetchColumn() == 1, 'Disputa gerou duas mesas abertas');
echo "OK: abertura de mesa funciona e segundo aparelho nao ocupa o mesmo recurso\n";

foreach (['vendas', 'movimentacoes', 'contas_receber', 'caixa', 'despesas', 'banco_pix', 'caixa_turno'] as $tabela) {
    $pdo->exec("DELETE FROM `$tabela`");
}
fixture($pdo, 'despesas', ['id' => 1, 'empresa' => 32, 'nome' => 'Venda']);
fixture($pdo, 'despesas', ['id' => 2, 'empresa' => 32, 'nome' => 'Contas à Receber']);
$venda = ['empresa' => '32', 'id_usuario' => '1', 'id_operacao' => str_repeat('6', 48),
    'acao' => 'venda', 'dados' => [
        'id' => '0', 'id_comanda' => '0', 'id_mesa' => '0', 'cliente' => '0',
        'caixa_id' => '0', 'valor_original' => '144.00', 'valor_lancamento' => '20.00',
        'pagamentoSelecionado' => 1, 'quantidadePessoas' => 0, 'subTotal' => '144.00',
        'parcelas' => '0', 'parcelasLista' => [], 'dataLancamento' => '2026-09-12',
        'valortroco' => '0', 'tipo' => 'Balcão', 'id_endereco' => '0',
        'obs' => "Pedido d'Agua", 'tipodeentrega' => '1', 'produtos' => [$produto]]];
$produto['observacao'] = "Sem cebola d'Agua";
$venda['dados']['produtos'] = [$produto];
$reciboVenda = garcomOperacao($pdo, $venda);
verificar(garcomOperacao($pdo, $venda) === $reciboVenda, 'Venda repetida nao recuperou recibo');
verificar($pdo->query('SELECT COUNT(*) FROM vendas')->fetchColumn() == 1, 'Venda duplicada');
verificar($pdo->query('SELECT COUNT(*) FROM movimentacoes')->fetchColumn() == 1, 'Pagamento duplicado');
verificar($pdo->query("SELECT COUNT(*) FROM itens_venda WHERE tipo_status = 'Balcão'")->fetchColumn() == 1, 'Itens de venda duplicados');
verificar($pdo->query("SELECT observacao FROM itens_venda WHERE tipo_status = 'Balcão'")->fetchColumn() === $produto['observacao'], 'Observacao da venda incorreta');
echo "OK: venda offline grava itens, bordas, observacao e pagamento uma unica vez\n";

$pagamento = $venda;
$pagamento['id_operacao'] = str_repeat('7', 48);
$pagamento['dados']['id_venda_origem'] = $venda['id_operacao'];
$pagamento['dados']['valor_lancamento'] = '124.00';
$pagamento['dados']['produtos'] = [];
$segundoPagamento = garcomOperacao($pdo, $pagamento);
verificar(garcomOperacao($pdo, $pagamento) === $segundoPagamento, 'Pagamento parcial duplicado');
verificar($pdo->query('SELECT COUNT(*) FROM movimentacoes')->fetchColumn() == 2, 'Pagamento complementar nao registrado uma vez');
verificar($pdo->query('SELECT SUM(valor) FROM movimentacoes')->fetchColumn() == 144, 'Soma dos pagamentos incorreta');
echo "OK: pagamentos parciais offline usam a mesma venda e recibos independentes\n";
$pagamento['id_operacao'] = str_repeat('8', 48);
$pdo->prepare("UPDATE vendas SET status = 'Cancelada' WHERE id = ?")->execute([$reciboVenda['idVenda']]);
esperarConflito($pdo, $pagamento);
verificar($pdo->query('SELECT COUNT(*) FROM movimentacoes')->fetchColumn() == 2, 'Venda cancelada recebeu pagamento');
echo "OK: pagamento atrasado de venda cancelada fica em conflito\n";

$falhaVenda = $venda;
$falhaVenda['id_operacao'] = str_repeat('9', 48);
$falhaVenda['dados']['produtos'][] = $produto;
$pdoFalha = conectarTeste();
$pdoFalha->falharNoSegundo = true;
try {
    garcomOperacao($pdoFalha, $falhaVenda);
    throw new LogicException('Falha da venda nao ocorreu');
} catch (RuntimeException $e) {
    verificar(!($e instanceof LogicException), $e->getMessage());
}
verificar($pdo->query('SELECT COUNT(*) FROM vendas')->fetchColumn() == 1, 'Venda parcial ficou gravada');
verificar($pdo->query('SELECT COUNT(*) FROM movimentacoes')->fetchColumn() == 2, 'Rollback da venda criou pagamento');
echo "OK: falha em produto reverte venda, complementos e pagamento\n";

fixture($pdo, 'caixa', ['id' => 9, 'empresa' => 32, 'usuario_ab' => 1, 'status' => 'Aberto']);
$venda['id_operacao'] = str_repeat('0', 48);
esperarConflito($pdo, $venda);
verificar($pdo->query('SELECT COUNT(*) FROM vendas')->fetchColumn() == 1, 'Venda foi registrada no caixa errado');
echo "OK: mudanca de caixa impede lancamento financeiro em sessao diferente\n";

// O fechamento desktop e a sincronizacao agora disputam a mesma linha InnoDB.
fixture($pdo, 'comandas_pedidos', ['id' => 300, 'empresa' => 32, 'id_comanda' => 30,
    'id_mesa' => 0, 'status' => 'Andamento', 'data_abertura' => '2026-09-22',
    'hora_abertura' => '12:00:00', 'hash' => 'fechamento-concorrente', 'pago' => 'Não']);
$concorrente = $entrada;
$concorrente['id_operacao'] = bin2hex(random_bytes(24));
$concorrente['dados']['id_comanda_pedido'] = '300';
$concorrente['dados']['id_comanda'] = '30';
$concorrente['dados']['versao_atendimento'] = garcomVersao(
    $pdo->query('SELECT * FROM comandas_pedidos WHERE id = 300')->fetch(PDO::FETCH_ASSOC));
$sinais = stream_socket_pair(STREAM_PF_UNIX, STREAM_SOCK_STREAM, STREAM_IPPROTO_IP);
$filho = pcntl_fork();
if ($filho === 0) {
    fclose($sinais[0]);
    fgets($sinais[1]);
    esperarConflito(conectarTeste(), $concorrente);
    exit(0);
}
fclose($sinais[1]);
$fechamento = conectarTeste();
iniciarRecebimentoAtendimentoDesktop($fechamento, ['empresa' => '32', 'id' => '300', 'id_comanda' => '30'], 'comanda');
fwrite($sinais[0], "bloqueado\n");
usleep(150000);
$fechamento->exec("UPDATE comandas_pedidos SET status = 'Finalizada', data_fechamento = CURDATE() WHERE id = 300");
$fechamento->commit();
pcntl_waitpid($filho, $status);
verificar(pcntl_wexitstatus($status) === 0, 'Sincronizacao concorrente nao respeitou fechamento');
$pdo = conectarTeste();
verificar($pdo->query('SELECT COUNT(*) FROM itens_venda WHERE id_comanda_pedido = 300')->fetchColumn() == 0,
    'Conta encerrada recebeu item durante o pagamento');
echo "OK: fechamento desktop concorrente impede insercao atrasada pelo app\n";

// Delivery direto offline usa o mesmo recibo: nunca confirma apenas metade do pedido.
fixture($pdo, 'clientes', ['id' => 8, 'empresa' => 32, 'nome' => "Cliente D'Agua", 'razao_social' => "Cliente D'Agua"]);
fixture($pdo, 'enderecos_clientes', ['id' => 9, 'id_cliente' => 8, 'id_empresa' => 32]);
fixture($pdo, 'opcoes_carrossel', ['id' => 1, 'empresa' => 32, 'ativo' => 'Sim', 'sequencia' => 1]);
$direto = ['empresa' => '32', 'id_usuario' => '1', 'id_operacao' => bin2hex(random_bytes(24)), 'acao' => 'delivery',
    'dados' => ['cliente' => '8', 'endereco' => '9', 'tipoentrega' => '1', 'concluido' => true,
        'obs' => "Pedido d'agua, sem cebola", 'valor_da_entrega' => '4', 'valor_desconto' => '0',
        'valor_acrescimo' => '0', 'caixa_id' => '9',
        'produtos' => [['id' => '5', 'quantidade' => 1, 'valorVenda' => 45,
            'observacao' => "Sem cebola, d'agua", 'opcoesPacotesListaFinal' => []]],
        'pagamentos' => [
            ['pagamentoSelecionado' => '1', 'valor_lancamento' => '20', 'valortroco' => '0', 'dataLancamento' => date('Y-m-d')],
            ['pagamentoSelecionado' => '1', 'valor_lancamento' => '30', 'valortroco' => '1', 'dataLancamento' => date('Y-m-d')],
        ]]];
$reciboDelivery = garcomOperacao($pdo, $direto);
verificar($reciboDelivery['saldo'] === '0.00' && (int)$reciboDelivery['idVenda'] > 0, 'Delivery quitado nao gerou venda');
verificar(garcomOperacao($pdo, $direto) === $reciboDelivery, 'Delivery perdeu recibo no reenvio');
$idDelivery = (int)$reciboDelivery['idDelivery'];
verificar($pdo->query("SELECT COUNT(*) FROM movimentacoes WHERE id_mov = $idDelivery AND tipo_de_finalizarcao = 'Delivery'")->fetchColumn() == 2,
    'Delivery duplicou pagamento');
verificar($pdo->query("SELECT SUM(valor) FROM movimentacoes WHERE id_mov = $idDelivery AND tipo_de_finalizarcao = 'Delivery'")->fetchColumn() == 49,
    'Pagamento com troco incorreto');
verificar($pdo->query("SELECT COUNT(*) FROM itens_venda WHERE id_delivery = $idDelivery")->fetchColumn() == 1, 'Delivery duplicou itens');
echo "OK: Delivery direto com pagamentos parciais, troco e venda idempotentes\n";

$aPrazo = $direto;
$aPrazo['id_operacao'] = bin2hex(random_bytes(24));
$aPrazo['dados']['pagamentos'] = [['pagamentoSelecionado' => '2', 'valor_lancamento' => '49',
    'valortroco' => '0', 'dataLancamento' => date('Y-m-d'), 'parcelas' => 2,
    'parcelasLista' => [json_encode(['valor' => '24.50', 'vencimento' => '2026-10-01']),
        json_encode(['valor' => '24.50', 'vencimento' => '2026-11-01'])]]];
$reciboPrazo = garcomOperacao($pdo, $aPrazo);
garcomOperacao($pdo, $aPrazo);
$idPrazo = (int)$reciboPrazo['idDelivery'];
verificar($pdo->query("SELECT COUNT(*) FROM contas_receber WHERE id_venda = $idPrazo AND tipo_de_finalizarcao = 'Delivery'")->fetchColumn() == 2,
    'Conta parcelada duplicada');
echo "OK: Delivery em conta conserva parcelas e reenvio unico\n";

$falhaDelivery = $direto;
$falhaDelivery['id_operacao'] = bin2hex(random_bytes(24));
$falhaDelivery['dados']['produtos'][] = $falhaDelivery['dados']['produtos'][0];
$qtdDelivery = $pdo->query('SELECT COUNT(*) FROM delivery')->fetchColumn();
$qtdPagamentos = $pdo->query('SELECT COUNT(*) FROM movimentacoes')->fetchColumn();
$pdoFalha = conectarTeste();
$pdoFalha->falharNoSegundo = true;
try {
    garcomOperacao($pdoFalha, $falhaDelivery);
    throw new LogicException('Falha do Delivery nao ocorreu');
} catch (RuntimeException $e) {
    verificar(!($e instanceof LogicException), $e->getMessage());
}
verificar($pdo->query('SELECT COUNT(*) FROM delivery')->fetchColumn() == $qtdDelivery, 'Delivery parcial permaneceu no servidor');
verificar($pdo->query('SELECT COUNT(*) FROM movimentacoes')->fetchColumn() == $qtdPagamentos, 'Delivery incompleto gerou pagamento');
echo "OK: falha em item reverte Delivery, pagamentos e recibo\n";

// Uma comanda mantem a identidade mas sua mesa foi assumida por outra comanda.
$idSecundario = (int)$pdo->query('SELECT MAX(id) FROM comandas_pedidos')->fetchColumn() + 1;
$idOcupante = $idSecundario + 1;
fixture($pdo, 'comandas_pedidos', ['id' => $idSecundario, 'empresa' => 32, 'id_comanda' => 31,
    'id_mesa' => 31, 'status' => 'Andamento', 'data_abertura' => '2026-09-22',
    'data_fechamento' => null, 'hora_abertura' => '12:00:00', 'hash' => 'mesa-secundaria']);
fixture($pdo, 'comandas_pedidos', ['id' => $idOcupante, 'empresa' => 32, 'id_comanda' => 32,
    'id_mesa' => 31, 'status' => 'Andamento', 'data_abertura' => '2026-09-22',
    'data_fechamento' => null, 'hora_abertura' => '12:01:00', 'hash' => 'mesa-ocupada']);
$secundaria = $entrada;
$secundaria['id_operacao'] = bin2hex(random_bytes(24));
$secundaria['dados']['id_comanda_pedido'] = (string)$idSecundario;
$secundaria['dados']['id_comanda'] = '31';
$secundaria['dados']['id_mesa'] = '31';
$secundaria['dados']['versao_atendimento'] = garcomVersao(
    $pdo->query('SELECT * FROM comandas_pedidos WHERE id = ' . $idSecundario)->fetch(PDO::FETCH_ASSOC));
esperarConflito($pdo, $secundaria);
verificar($pdo->query('SELECT COUNT(*) FROM itens_venda WHERE id_comanda_pedido = ' . $idSecundario)->fetchColumn() == 0,
    'Comanda recebeu itens mesmo com mesa vinculada reutilizada');
$pdo->exec('UPDATE comandas_pedidos SET id_comanda = 0 WHERE id = ' . $idOcupante);
garcomOperacao($pdo, $secundaria);
echo "OK: recurso secundario protege comanda sem impedir vinculo ao registro proprio da mesa\n";
