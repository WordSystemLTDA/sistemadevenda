<?php
// Somente a instancia descartavel; nunca usa conexao.php nem a rede do restaurante.
require_once $argv[1] . '/api_restaurantes_venda/api1/transferencias/operacoes.php';

class PdoTransferenciaTeste extends PDO {
    public $falharHistorico = false;
    public function prepare($sql, $options = []) {
        if ($this->falharHistorico && strpos($sql, 'INSERT INTO garcom_transferencias') !== false) {
            throw new RuntimeException('Falha simulada no historico');
        }
        return parent::prepare($sql, $options);
    }
}
function bancoTeste() {
    $pdo = new PdoTransferenciaTeste('mysql:unix_socket=/private/tmp/garcom-mariadb-test.sock;dbname=eadsagestart;charset=utf8mb4',
        'root', '', [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    if (strpos($pdo->query('SELECT @@datadir')->fetchColumn(), '/private/tmp/garcom-mariadb-test/') !== 0) {
        throw new RuntimeException('Banco nao autorizado');
    }
    $pdo->exec("SET SESSION sql_mode = ''");
    return $pdo;
}
function verificar($ok, $mensagem) { if (!$ok) throw new RuntimeException($mensagem); }
function inserir($pdo, $tabela, $dados) {
    $campos = implode('`,`', array_keys($dados));
    $marcadores = implode(',', array_fill(0, count($dados), '?'));
    $pdo->prepare("INSERT INTO `$tabela` (`$campos`) VALUES ($marcadores)")->execute(array_values($dados));
}
function preparar($pdo, $tipo, $livre = false) {
    foreach (['garcom_transferencias', 'garcom_operacoes', 'itens_venda_adicionais', 'itens_venda',
        'comandas_pedidos', 'comandas', 'mesa', 'usuarios', 'permissoes_empresa'] as $tabela) $pdo->exec("DELETE FROM `$tabela`");
    inserir($pdo, 'usuarios', ['id' => 1, 'empresa' => 32, 'ativo' => 'Sim']);
    inserir($pdo, 'permissoes_empresa', ['empresa' => 32, 'numero_pedido' => 100]);
    $tabela = $tipo === 'mesa' ? 'mesa' : 'comandas';
    for ($i = 1; $i <= 2; $i++) {
        inserir($pdo, $tabela, ['id' => $i, 'empresa' => 32, 'nome' => "$tipo: $i", 'ativo' => 'Sim', 'hash' => "recurso$i"]);
        if ($i === 2 && $livre) continue;
        inserir($pdo, 'comandas_pedidos', ['id' => 100 + $i, 'empresa' => 32,
            'id_comanda' => $tipo === 'comanda' ? $i : 0, 'id_mesa' => $tipo === 'mesa' ? $i : 0,
            'status' => 'Andamento', 'hash' => "sessao$i", 'data_abertura' => '2026-09-12',
            'hora_abertura' => '12:00:00', 'observacoes' => "Cliente d'Agua $i", 'valor_pago' => 0, 'pago' => 'Não']);
        inserir($pdo, 'itens_venda', ['id' => $i, 'id_comanda_pedido' => 100 + $i,
            'id_comanda' => $tipo === 'comanda' ? $i : 0, 'id_mesa' => $tipo === 'mesa' ? $i : 0,
            'empresa' => 32, 'produto' => 5, 'quantidade' => 1, 'total' => $i * 12.34,
            'status_de_envio' => 'Enviado', 'notificacao_realizada' => 'Sim', 'observacao' => 'Sem cebola']);
    }
    inserir($pdo, 'itens_venda_adicionais', ['id' => 1, 'id_itens_venda' => 1, 'empresa' => 32]);
}
function entrada($pdo, $tipo) {
    return ['empresa' => '32', 'id_usuario' => '1', 'id_operacao' => bin2hex(random_bytes(24)),
        'acao' => 'transferencia', 'dados' => ['tipo' => $tipo, 'origem' => '1', 'destino' => '2',
            'versao_origem' => garcomRetratoTransferencia($pdo, '32', $tipo, '1')['versao'],
            'versao_destino' => garcomRetratoTransferencia($pdo, '32', $tipo, '2')['versao']]];
}
function rejeitar($pdo, $pedido) {
    try { garcomOperacao($pdo, $pedido); }
    catch (ConflitoGarcom $e) { return; }
    catch (InvalidArgumentException $e) { return; }
    catch (UnexpectedValueException $e) { return; }
    throw new RuntimeException('Transferencia insegura aceita');
}

$pdo = bancoTeste();
// A estrutura continua tendo uma unica fonte; provisionamento restrito ao banco de teste.
if (!$pdo->query("SHOW TABLES LIKE 'garcom_transferencias'")->fetchColumn()) {
    preg_match('/CREATE TABLE `garcom_transferencias` \(.*?;\n/s', file_get_contents($argv[1] . '/schema.sql'), $definicao);
    verificar(isset($definicao[0]), 'Tabela ausente no schema oficial');
    $pdo->exec($definicao[0]);
}
foreach (['comanda', 'mesa'] as $tipo) {
    foreach ([false, true] as $livre) {
        preparar($pdo, $tipo, $livre);
        $pedido = entrada($pdo, $tipo);
        $resposta = garcomOperacao($pdo, $pedido);
        verificar($resposta['sucesso'], 'Falha na transferencia');
        verificar($pdo->query("SELECT status FROM comandas_pedidos WHERE id = 101")->fetchColumn() === 'Transferida', 'Origem nao preservada');
        verificar(garcomRecurso($pdo, '32', $tipo, '1')['livre'], 'Origem nao liberada');
        verificar(!garcomRecurso($pdo, '32', $tipo, '2')['livre'], 'Destino nao ocupado');
        verificar($resposta['total'] == ($livre ? 12.34 : 37.02), 'Soma incorreta');
        $idDestino = $resposta['id_comanda_pedido'];
        $item = $pdo->query('SELECT * FROM itens_venda WHERE id = 1')->fetch(PDO::FETCH_ASSOC);
        verificar($item['id_comanda_pedido'] == $idDestino && $item['id_' . $tipo] == 2, 'Destino do item incorreto');
        verificar($item['status_de_envio'] === 'Enviado' && $item['notificacao_realizada'] === 'Sim' &&
            $item['observacao'] === 'Sem cebola', 'Preparo foi alterado');
        verificar($pdo->query('SELECT id_itens_venda FROM itens_venda_adicionais WHERE id = 1')->fetchColumn() == 1, 'Adicional perdido');
        verificar($pdo->query('SELECT COUNT(*) FROM garcom_transferencias')->fetchColumn() == 1, 'Historico ausente');
        verificar(garcomOperacao($pdo, $pedido) === $resposta, 'Reenvio nao recupera recibo');
        verificar($pdo->query('SELECT COUNT(*) FROM garcom_transferencias')->fetchColumn() == 1, 'Historico duplicado');
        $pdo->exec("UPDATE comandas_pedidos SET status = 'Finalizada' WHERE id = " . (int)$idDestino);
        verificar(garcomOperacao($pdo, $pedido) === $resposta, 'Reenvio alterou atendimento ja encerrado');
        echo "OK: $tipo -> " . ($livre ? 'livre' : 'ocupada') . "; soma, origem livre, historico, adicionais, preparo e recibo\n";
    }
}

foreach (['novo_item', 'fechamento', 'reutilizada', 'livre_reutilizada', 'pago', 'ajuste', 'item_pago',
    'outra_empresa', 'mesmo_destino', 'mesmo_destino_zero', 'usuario_inativo', 'mesa_vinculada', 'versao', 'origem_alterada'] as $cenario) {
    $tipo = $cenario === 'mesa_vinculada' ? 'mesa' : 'comanda';
    preparar($pdo, $tipo, $cenario === 'livre_reutilizada');
    $pedido = entrada($pdo, $tipo);
    switch ($cenario) {
        case 'novo_item': inserir($pdo, 'itens_venda', ['id' => 3, 'empresa' => 32, 'id_comanda_pedido' => 102, 'total' => 5]); break;
        case 'fechamento': $pdo->exec("UPDATE comandas_pedidos SET status = 'Fechamento' WHERE id = 102"); break;
        case 'reutilizada': $pdo->exec("UPDATE comandas_pedidos SET hash = 'nova-sessao' WHERE id = 102"); break;
        case 'livre_reutilizada': inserir($pdo, 'comandas_pedidos', ['id' => 103, 'empresa' => 32, 'id_comanda' => 2, 'status' => 'Finalizada']); break;
        case 'pago': $pdo->exec('UPDATE comandas_pedidos SET valor_pago = 10 WHERE id = 101'); $pedido = entrada($pdo, $tipo); break;
        case 'ajuste': $pdo->exec('UPDATE comandas_pedidos SET valor_desconto = 5 WHERE id = 102'); $pedido = entrada($pdo, $tipo); break;
        case 'item_pago': $pdo->exec('UPDATE itens_venda SET id_venda = 22 WHERE id = 1'); $pedido = entrada($pdo, $tipo); break;
        case 'outra_empresa': $pdo->exec('UPDATE comandas SET empresa = 33 WHERE id = 2'); break;
        case 'mesmo_destino': $pedido['dados']['destino'] = '1'; break;
        case 'mesmo_destino_zero': $pedido['dados']['destino'] = '01'; break;
        case 'usuario_inativo': $pdo->exec("UPDATE usuarios SET ativo = 'Não'"); break;
        case 'mesa_vinculada': $pdo->exec('UPDATE comandas_pedidos SET id_comanda = 4 WHERE id = 101'); $pedido = entrada($pdo, $tipo); break;
        case 'versao': $pedido['dados']['versao_destino'] = ''; break;
        case 'origem_alterada': $pdo->exec("UPDATE comandas_pedidos SET status = 'Transferida' WHERE id = 101"); break;
    }
    rejeitar($pdo, $pedido);
    verificar($pdo->query('SELECT COUNT(*) FROM garcom_transferencias')->fetchColumn() == 0, 'Gravou historico de rejeicao');
    verificar($pdo->query('SELECT id_comanda_pedido FROM itens_venda WHERE id = 1')->fetchColumn() == 101, 'Moveu item apesar da rejeicao');
    echo "OK: rejeita $cenario sem mover pedidos\n";
}

preparar($pdo, 'comanda', true);
$pedido = entrada($pdo, 'comanda');
$pdo->falharHistorico = true;
try { garcomOperacao($pdo, $pedido); throw new LogicException('Nao simulou falha'); }
catch (RuntimeException $e) { verificar(!($e instanceof LogicException), 'Nao simulou falha'); }
$pdo->falharHistorico = false;
verificar($pdo->query('SELECT COUNT(*) FROM comandas_pedidos')->fetchColumn() == 1, 'Abertura nao revertida');
verificar($pdo->query('SELECT id_comanda_pedido FROM itens_venda WHERE id = 1')->fetchColumn() == 101, 'Itens nao revertidos');
verificar($pdo->query('SELECT COUNT(*) FROM garcom_operacoes')->fetchColumn() == 0, 'Recibo de transferencia incompleta');
echo "OK: falha no historico reverte abertura, itens, origem e recibo\n";

$filho = pcntl_fork();
if ($filho === 0) { garcomOperacao(bancoTeste(), $pedido); exit(0); }
garcomOperacao(bancoTeste(), $pedido);
pcntl_waitpid($filho, $status);
verificar(pcntl_wexitstatus($status) === 0, 'Processo concorrente falhou');
$pdo = bancoTeste();
verificar($pdo->query('SELECT COUNT(*) FROM garcom_transferencias')->fetchColumn() == 1, 'Concorrencia duplicou historico');
verificar($pdo->query('SELECT COUNT(*) FROM comandas_pedidos')->fetchColumn() == 2, 'Concorrencia duplicou abertura');
echo "OK: duas conexoes simultaneas confirmam apenas uma transferencia\n";

$pedido['dados']['destino'] = '1';
rejeitar($pdo, $pedido);
echo "OK: identificador repetido com outro conteudo recusado\n";

foreach (['mesa', 'comanda'] as $tipo) {
    preparar($pdo, $tipo);
    garcomOperacao($pdo, entrada($pdo, $tipo));
    try {
        garcomPedidoLegado($pdo, ['empresa' => '32', 'id_usuario' => '1', 'id_comanda_pedido' => '101',
            'id_comanda' => $tipo === 'comanda' ? '1' : '0', 'id_mesa' => $tipo === 'mesa' ? '1' : '0', 'produtos' => []], $tipo);
        throw new RuntimeException('Rota legada aceitou origem transferida');
    } catch (ConflitoGarcom $e) {}
    verificar($pdo->query('SELECT COUNT(*) FROM itens_venda WHERE id_comanda_pedido = 101')->fetchColumn() == 0, 'Legado enviou para origem transferida');
    echo "OK: envio legado de $tipo rejeita atendimento transferido\n";
}
