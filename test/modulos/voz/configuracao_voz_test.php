<?php
$base = getenv('API_GARCOM_TESTE') ?: '/Applications/XAMPP/xamppfiles/htdocs/sistema/apis_restaurantes/api_restaurantes_venda/api1';
require_once $base . '/voz/seguranca.php';
require_once $base . '/voz/interpretacao.php';
require_once $base . '/voz/abertura.php';

class ConfiguracaoVozPdoTeste extends PDO
{
    public $empresas = [];
    public $indisponivel = false;
    public function __construct() {}
    public function prepare($sql, $opcoes = [])
    {
        if ($this->indisponivel) throw new PDOException('Banco indisponivel no teste');
        if (strpos($sql, 'WHERE empresa = ? AND integracao = ?') === false) {
            throw new RuntimeException('Consulta precisa isolar empresa e integracao');
        }
        return new ConfiguracaoVozConsultaTeste($this);
    }
}

class ConfiguracaoVozConsultaTeste extends PDOStatement
{
    private $pdo;
    private $empresa;
    private $integracao;
    public function __construct(ConfiguracaoVozPdoTeste $pdo) { $this->pdo = $pdo; }
    public function execute($parametros = null)
    {
        if (!in_array($parametros[1], ['openai', 'comanda_voz'], true)) throw new RuntimeException('Integracao incorreta');
        $this->integracao = $parametros[1];
        $this->empresa = $parametros[0];
        return true;
    }
    public function fetchAll($modo = null, $argumento = null, $args = null)
    {
        $linhas = [];
        if ($this->integracao === 'comanda_voz') return $linhas;
        foreach ($this->pdo->empresas[$this->empresa] ?? [] as $chave => $valor) {
            $linhas[] = ['chave' => $chave, 'valor' => $valor];
        }
        return $linhas;
    }
}

$testes = 0;
function conferir($condicao, string $descricao): void
{
    global $testes;
    if (!$condicao) throw new RuntimeException($descricao);
    $testes++;
}
function rejeitar(callable $acao, string $descricao): void
{
    try { $acao(); } catch (Throwable $erro) { conferir(true, $descricao); return; }
    conferir(false, $descricao);
}

foreach (['OPENAI_API_KEY', 'GARCOM_VOZ_EMPRESAS', 'GARCOM_VOZ_SEGREDO',
    'GARCOM_VOZ_MODELO', 'GARCOM_VOZ_TRANSCRICAO', 'GARCOM_VOZ_HTTP_LOCAL'] as $variavel) {
    putenv($variavel);
}
$pdo = new ConfiguracaoVozPdoTeste();
$pdo->empresas = [
    '32' => ['habilitado' => 'true', 'api_key' => ' chave-ficticia-A ', 'modelo' => 'modelo-teste-A'],
    '33' => ['habilitado' => 'true', 'api_key' => 'chave-ficticia-B'],
    '34' => ['habilitado' => 'false', 'api_key' => 'chave-ficticia-C'],
    '35' => ['habilitado' => 'true', 'api_key' => ''],
];
conferir(vozHabilitada('32', $pdo), 'painel habilita sem variaveis manuais');
conferir(vozConfiguracaoOpenAI('32', $pdo)['api_key'] === 'chave-ficticia-A', 'chave do painel normalizada');
conferir(vozConfiguracaoOpenAI('33', $pdo)['api_key'] === 'chave-ficticia-B', 'chave isolada por empresa');
conferir(!vozHabilitada('34', $pdo), 'integracao desativada');
conferir(!vozHabilitada('35', $pdo), 'chave vazia');
conferir(!vozHabilitada('36', $pdo), 'empresa sem configuracao nao herda outra chave');
conferir(!vozHabilitada('', $pdo), 'empresa vazia');
rejeitar(fn() => vozExigirConfiguracao('35', $pdo), 'erro explicito de chave ausente');
$config = vozExigirConfiguracao('32', $pdo);
conferir(vozRequisicao('pedido', $config['modelo'])['model'] === 'modelo-teste-A', 'modelo salvo usado no pedido');
conferir(vozRequisicaoAbertura('mesa 1', 'mesa', $config['modelo'])['model'] === 'modelo-teste-A', 'modelo salvo usado na abertura');
conferir($config['transcricao'] === 'gpt-4o-mini-transcribe', 'transcricao tem modelo proprio');
conferir(vozConfiguracaoOpenAI('33', $pdo)['modelo'] === 'gpt-4.1-mini', 'modelo padrao com campo vazio');

$segredo = vozSegredo();
conferir(strlen($segredo) === 64 && vozSegredo() === $segredo, 'segredo aleatorio persistente');
$token = vozToken('32', '7', 1000, $pdo);
$identidade = vozValidarToken($token, 1001, $pdo);
conferir($identidade['empresa'] === '32' && $identidade['usuario'] === '7', 'sessao assinada sem ambiente');
conferir(!isset($identidade['api_key']) && !isset($identidade['segredo']), 'token nao contem segredos');
rejeitar(fn() => vozValidarToken($token . 'x', 1001, $pdo), 'assinatura alterada rejeitada');
rejeitar(fn() => vozValidarToken($token, 44200, $pdo), 'sessao expirada');
$pdo->empresas['32']['habilitado'] = 'false';
rejeitar(fn() => vozValidarToken($token, 1001, $pdo), 'desativacao revoga sessao existente');
$pdo->empresas['32']['habilitado'] = 'true';
$partes = explode('.', $token);
$dados = json_decode(base64_decode($partes[0]), true);
$dados['empresa'] = '33';
rejeitar(fn() => vozValidarToken(base64_encode(json_encode($dados)) . '.' . $partes[1], 1001, $pdo), 'troca de empresa rejeitada');
putenv('GARCOM_VOZ_SEGREDO=curto');
rejeitar(fn() => vozToken('32', '7', 1000, $pdo), 'segredo manual invalido rejeitado');
putenv('GARCOM_VOZ_SEGREDO');

putenv('OPENAI_API_KEY=chave-ficticia-legada');
conferir(!vozHabilitada('36', $pdo), 'ambiente sem liberacao nao habilita empresa');
putenv('GARCOM_VOZ_EMPRESAS=32, 34,35,36');
conferir(vozConfiguracaoOpenAI('32', $pdo)['api_key'] === 'chave-ficticia-A', 'painel tem prioridade sobre ambiente');
conferir(!vozHabilitada('33', $pdo), 'lista administrativa restringe painel');
conferir(!vozHabilitada('34', $pdo) && !vozHabilitada('35', $pdo), 'ambiente nao contorna desativacao nem chave vazia');
conferir(vozHabilitada('36', $pdo), 'compatibilidade com instalacao legada explicitamente liberada');
$pdo->indisponivel = true;
rejeitar(fn() => vozConfiguracaoOpenAI('32', $pdo), 'falha no banco nao recorre a chave de outra origem');

$_SERVER = ['REMOTE_ADDR' => '192.168.2.10', 'SERVER_ADDR' => '192.168.2.113'];
rejeitar(fn() => vozExigirTransporteSeguro(), 'HTTP privado exige opt-in no servidor');
$_SERVER['HTTP_GARCOM_VOZ_HTTP_LOCAL'] = '1';
$_SERVER['HTTP_X_FORWARDED_PROTO'] = 'https';
rejeitar(fn() => vozExigirTransporteSeguro(), 'headers do cliente nao liberam HTTP');
$_SERVER['GARCOM_VOZ_HTTP_LOCAL'] = '1';
vozExigirTransporteSeguro();
conferir(true, 'HTTP privado com opt-in');
$_SERVER['REMOTE_ADDR'] = '8.8.8.8';
rejeitar(fn() => vozExigirTransporteSeguro(), 'origem publica bloqueada em HTTP');
$_SERVER['REMOTE_ADDR'] = '192.168.2.10';
$_SERVER['SERVER_ADDR'] = '8.8.8.8';
rejeitar(fn() => vozExigirTransporteSeguro(), 'destino publico bloqueado em HTTP');
$_SERVER['HTTPS'] = 'on';
vozExigirTransporteSeguro();
conferir(true, 'HTTPS continua aceito');
foreach (['10.0.0.1', '172.16.0.1', '172.31.255.254', '192.168.2.113', '127.0.0.1', '::1'] as $ip) {
    conferir(vozIpLocal($ip), 'IP local permitido: ' . $ip);
}
foreach (['172.15.0.1', '172.32.0.1', '192.169.0.1', '8.8.8.8', '10.0.0.1.example', '10.999.0.1', ''] as $ip) {
    conferir(!vozIpLocal($ip), 'IP nao privado rejeitado: ' . $ip);
}
echo "$testes verificacoes passaram; sem banco real, OpenAI ou pedidos.\n";
