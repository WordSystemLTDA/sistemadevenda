<?php
require_once $argv[1] . '/api_restaurantes_venda/api1/indicadores/consulta.php';
date_default_timezone_set('America/Sao_Paulo');
$pdo = new PDO('mysql:unix_socket=/private/tmp/garcom-mariadb-test.sock;dbname=eadsagestart;charset=utf8mb4', 'root', '', [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
if (strpos($pdo->query('SELECT @@datadir')->fetchColumn(), '/private/tmp/garcom-mariadb-test/') !== 0) {
    throw new RuntimeException('Banco nao autorizado para testes');
}
$pdo->exec("SET SESSION sql_mode = 'ONLY_FULL_GROUP_BY'");

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
function recusar(callable $acao, int $codigo) {
    try { $acao(); } catch (RuntimeException $e) {
        verificar($e->getCode() === $codigo, 'Codigo inesperado'); return;
    }
    throw new RuntimeException('Requisicao indevida aceita');
}
foreach (['usuarios', 'comandas_pedidos', 'itens_venda', 'vendas'] as $tabela) $pdo->exec("DELETE FROM `$tabela`");
fixture($pdo, 'usuarios', ['id' => 1, 'empresa' => 32, 'ativo' => 'Sim', 'nivel' => '1', 'email' => 'gestor-teste', 'senha' => 'teste']);
$entrada = ['id_usuario' => '1', 'empresa' => '32', 'usuario' => 'gestor-teste', 'senha' => 'teste', 'inicio' => '2026-09-12', 'fim' => '2026-09-12'];
verificar(indicadoresAutenticar($pdo, $entrada) === 32, 'Administrador deve acessar');
recusar(fn() => indicadoresAutenticar($pdo, array_merge($entrada, ['senha' => 'errada'])), 401);
recusar(fn() => indicadoresAutenticar($pdo, array_merge($entrada, ['empresa' => '33'])), 403);
recusar(fn() => indicadoresAutenticar($pdo, array_merge($entrada, ['usuario' => "' OR 1=1 --"])), 401);
$pdo->exec("UPDATE usuarios SET nivel = '5' WHERE id = 1");
recusar(fn() => indicadoresAutenticar($pdo, array_merge($entrada, ['nivel' => '1'])), 403);
$pdo->exec("UPDATE usuarios SET nivel = '0', ativo = 'Nao' WHERE id = 1");
recusar(fn() => indicadoresAutenticar($pdo, $entrada), 401);
$pdo->exec("UPDATE usuarios SET ativo = 'Sim' WHERE id = 1");
verificar(indicadoresAutenticar($pdo, $entrada) === 32, 'Administrador nivel 0 deve acessar');
echo "OK: autenticacao, nivel autoritativo, revogacao, empresa e SQL injection\n";

foreach ([['2026-02-31','2026-03-01'], ['2026-09-13','2026-09-12'], ['2026-01-01','2026-04-01'], ['','2026-09-12']] as $datas) {
    recusar(fn() => indicadoresPeriodo(['inicio' => $datas[0], 'fim' => $datas[1]]), 422);
}
verificar(indicadoresPeriodo(['inicio' => '2024-02-29', 'fim' => '2024-02-29'])[1] === '2024-03-01', 'Bissexto');
verificar(indicadoresConsultar($pdo, 32, $entrada)['grupos'] === [], 'Periodo vazio');
echo "OK: datas, periodo vazio, limite de 90 dias e ano bissexto\n";

foreach ([
    [1,32,5,3,'Andamento','2026-09-12','00:00:00'],
    [2,32,5,3,'Finalizada','2026-09-12','19:30:00'],
    [3,32,0,4,'Fechamento','2026-09-12','23:59:59'],
    [4,32,6,0,'Cancelada','2026-09-12','19:35:00'],
    [5,33,7,0,'Andamento','2026-09-12','19:35:00'],
    [6,32,8,0,'Andamento','2026-09-13','00:00:00'],
    [7,32,9,0,'Andamento','2026-09-11','23:59:59'],
    [8,32,10,0,'Transferida','2026-09-12','19:30:00'],
] as $linha) {
    fixture($pdo, 'comandas_pedidos', array_combine(['id','empresa','id_comanda','id_mesa','status','data_abertura','hora_abertura'], $linha));
}
foreach ([[1,32,1,60.10],[2,32,1,12],[3,32,2,85],[4,32,3,25],[5,32,4,99],[6,33,1,1000]] as $linha) {
    fixture($pdo, 'itens_venda', array_combine(['id','empresa','id_comanda_pedido','total'], $linha));
}
foreach ([[1,32,'Balcão',0,'Concluída',40.20],[2,32,'Comanda',2,'Concluída',85],[3,32,'Balcão',2,'Concluída',85],
    [4,33,'Balcão',0,'Concluída',1000],[5,32,'Delivery',0,'Concluída',200], [6,32,'Balcão',0,'Cancelada',70]] as $linha) {
    fixture($pdo, 'vendas', array_merge(array_combine(['id','empresa','tipo_de_finalizarcao','id_comanda_pedido','status','subtotal'], $linha), ['data_lanc' => '2026-09-12', 'hora_lanc' => '19:00:00']));
}
$antes = [];
foreach (['comandas_pedidos','itens_venda','vendas'] as $tabela) $antes[$tabela] = $pdo->query("SELECT * FROM `$tabela` ORDER BY id")->fetchAll(PDO::FETCH_ASSOC);
$relatorio = indicadoresConsultar($pdo, 32, $entrada);
$validos = array_values(array_filter($relatorio['grupos'], fn($g) => $g['status'] !== 'Cancelada'));
verificar(array_sum(array_column($validos, 'quantidade')) === 4, 'Contagem duplicou mesa/comanda/venda ou cruzou empresa/data');
verificar(array_sum(array_column($validos, 'consumo_centavos')) === 22230, 'Consumo deve usar itens e subtotal, sem cancelados ou empresa alheia');
verificar(array_sum(array_column($relatorio['grupos'], 'quantidade')) === 6, 'Cancelamentos separados');
verificar(count(array_filter($validos, fn($g) => $g['hora'] === 0)) === 1, 'Inicio inclusivo');
verificar(count(array_filter($validos, fn($g) => $g['hora'] === 23 && $g['canal'] === 'Mesa')) === 1, 'Final do dia inclusivo');
foreach ($antes as $tabela => $linhas) verificar($linhas === $pdo->query("SELECT * FROM `$tabela` ORDER BY id")->fetchAll(PDO::FETCH_ASSOC), 'Consulta alterou pedidos');
echo "OK: agregado real, centavos, canais, reabertura, limites de data e nenhuma escrita em pedidos\n";
