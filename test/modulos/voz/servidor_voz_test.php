<?php
$base = getenv('API_GARCOM_TESTE') ?: '/Applications/XAMPP/xamppfiles/htdocs/sistema/apis_restaurantes/api_restaurantes_venda/api1';
require_once $base . '/voz/seguranca.php';
require_once $base . '/voz/interpretacao.php';
require_once $base . '/voz/abertura.php';
$testes = 0;
function conferir($condicao, $descricao) {
    global $testes;
    if (!$condicao) throw new RuntimeException($descricao);
    $testes++;
}
function rejeitar(callable $acao, string $descricao) {
    try { $acao(); } catch (Throwable $erro) { conferir(true, $descricao); return; }
    conferir(false, $descricao);
}
putenv('GARCOM_VOZ_EMPRESAS=32');
putenv('GARCOM_VOZ_SEGREDO=' . str_repeat('teste-nao-usar-', 4));
putenv('OPENAI_API_KEY=chave-falsa-somente-testes');
conferir(!vozHabilitada('33'), 'empresa nao autorizada');
conferir(vozToken('33', '1') === null, 'nao emitir token de outra empresa');
$token = vozToken('32', '1', 1000);
$identidade = vozValidarToken($token, 1001);
conferir($identidade['empresa'] === '32' && $identidade['usuario'] === '1', 'identidade assinada');
rejeitar(fn() => vozValidarToken($token . 'x', 1001), 'assinatura alterada');
rejeitar(fn() => vozValidarToken($token, 44200), 'expiracao inclusiva');
rejeitar(fn() => vozValidarToken('qualquer-token', 1001), 'token malformado');
putenv('GARCOM_VOZ_EMPRESAS=33');
rejeitar(fn() => vozValidarToken($token, 1001), 'revogacao da empresa');
putenv('GARCOM_VOZ_EMPRESAS=32');
putenv('OPENAI_API_KEY=');
conferir(!vozHabilitada('32'), 'sem chave desabilitado');
putenv('OPENAI_API_KEY=chave-falsa-somente-testes');
$request = vozRequisicao('Pizza G com mussarela e calabresa');
conferir($request['store'] === false, 'nao armazenar Responses');
conferir($request['input'][0]['role'] === 'user', 'fala tratada como dado');
conferir($request['text']['format']['strict'] === true, 'saida estruturada estrita');
conferir($request['text']['format']['schema']['additionalProperties'] === false, 'campos fechados');
conferir(!isset(vozSchema()['properties']['preco']) && !isset(vozSchema()['properties']['id_comanda']), 'modelo nao controla preco ou destino');
$plano = ['tipo'=>'pizza', 'produto'=>'', 'quantidade'=>1, 'tamanho'=>'G', 'sabores'=>['Mussarela','Calabresa'],
    'bordas'=>['Chocolate'], 'adicionais'=>[['nome'=>'Milho','quantidade'=>1]], 'observacao'=>'', 'esclarecimento'=>''];
$resposta = ['status'=>'completed','output'=>[['type'=>'message','content'=>[['type'=>'output_text','text'=>json_encode($plano)]]]]];
conferir(vozExtrairPlano($resposta) === $plano, 'extracao do contrato');
rejeitar(fn() => vozExtrairPlano(['status'=>'incomplete']), 'resposta truncada');
rejeitar(fn() => vozExtrairPlano(['status'=>'completed','output'=>[['content'=>[['type'=>'refusal']]]]]), 'recusa');
rejeitar(fn() => vozExtrairPlano(['status'=>'completed','output'=>[['content'=>[['type'=>'output_text','text'=>'{}']]]]]), 'objeto incompleto');
foreach (['mesa', 'comanda'] as $tipo) {
    $requisicao = vozRequisicaoAbertura('Abrir ' . $tipo . ' tres com o nome de Bruno Masson', $tipo);
    conferir($requisicao['store'] === false, 'abertura nao armazena Responses');
    conferir($requisicao['text']['format']['strict'] === true, 'abertura estruturada');
    conferir($requisicao['input'][0]['role'] === 'user', 'fala de abertura como dado');
    conferir(strpos($requisicao['instructions'], 'cliente_cadastrado APENAS') !== false,
        'nome livre nao seleciona cadastro implicitamente');
    $abertura = ['acao'=>'abrir', 'tipo'=>$tipo, 'numero'=>'3', 'mesa_vinculada'=>'',
        'observacao'=>'Bruno Masson', 'cliente_cadastrado'=>'', 'esclarecimento'=>''];
    $respostaAbertura = ['status'=>'completed','output'=>[['content'=>[
        ['type'=>'output_text','text'=>json_encode($abertura)]]]]];
    conferir(vozExtrairPlano($respostaAbertura, vozSchemaAbertura()) === $abertura, 'contrato de abertura');
    rejeitar(fn() => vozExtrairPlano($respostaAbertura), 'nao aceitar abertura como pedido de cozinha');
}
rejeitar(fn() => vozRequisicaoAbertura('Abrir mesa 3', 'balcao'), 'tipo fora de escopo');
conferir(!isset(vozSchemaAbertura()['properties']['id_cliente']), 'modelo nao determina ID do cliente');
conferir(vozClienteUnico([['id'=>700]]) === '700', 'cliente unico selecionado');
rejeitar(fn() => vozClienteUnico([]), 'cliente inexistente bloqueado');
rejeitar(fn() => vozClienteUnico([['id'=>700], ['id'=>701]]), 'homonimos bloqueados');
rejeitar(fn() => vozClienteUnico([['id'=>'0']]), 'cadastro invalido bloqueado');
$escopo = 'teste:' . bin2hex(random_bytes(16));
vozLimitarUso($escopo, 1, 1);
rejeitar(fn() => vozLimitarUso($escopo, 1, 1), 'limite de uso persistente');
$pasta = sys_get_temp_dir() . '/bigchef-voz-' . hash('sha256', realpath($base . '/voz'));
unlink($pasta . '/' . hash('sha256', $escopo));
echo "$testes verificacoes passaram; nenhuma chamada externa ou gravacao de pedidos.\n";
