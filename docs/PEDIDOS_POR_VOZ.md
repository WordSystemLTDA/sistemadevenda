# Configuracao dos pedidos por voz

O painel `sistemarestaurante` salva a OpenAI em Integracoes > IA, usando
`integracoes_config` com `empresa` da conta, `integracao = openai` e chaves
`habilitado`, `api_key` e `modelo`. O app `sistemadevenda` autentica o usuario
na API PHP do servidor selecionado. A API busca as credenciais no mesmo banco
e para a mesma empresa do login; a chave OpenAI nao e enviada ao app de voz.

Fonte PHP local: `api_restaurantes_venda/api1/voz/`. O resolvedor esta em
`configuracao.php`. Sessao, pedidos e consulta de clientes conferem a integracao,
inclusive para revogar sessoes quando ela for desativada. O modelo salvo e usado
na interpretacao de pedidos e aberturas; vazio usa `gpt-4.1-mini`. A transcricao
continua usando `GARCOM_VOZ_TRANSCRICAO` ou `gpt-4o-mini-transcribe`.

Configuracao existente no painel tem prioridade completa: chave vazia e
integracao desativada nao recorrem ao ambiente. Somente empresas sem registro
OpenAI podem usar `OPENAI_API_KEY`, mediante inclusao explicita na lista
`GARCOM_VOZ_EMPRESAS`. Quando essa lista existe, tambem restringe o painel.
Falha na leitura do banco interrompe a operacao.

`GARCOM_VOZ_SEGREDO` continua disponivel para instalacoes administradas. Sem
essa variavel, a API gera 32 bytes aleatorios e guarda o segredo de assinatura
na pasta privada `bigchef-voz-<hash-do-diretorio>` do temporario do PHP. O arquivo
`segredo-sessao` e protegido por `flock` e compartilhado entre os workers.
Essa pasta deve ficar fora do web root e restrita ao usuario do PHP. Apagar o
temporario invalida as sessoes; nova autenticacao gera outro segredo. Em varios
servidores, configurar o mesmo segredo pelo ambiente de todos os workers.

## Rede local

O app conserva HTTP apenas para IP literal RFC1918, loopback ou localhost.
Enderecos online continuam usando HTTPS e certificados validos. A API so aceita
HTTP quando `GARCOM_VOZ_HTTP_LOCAL=1` e tanto o IP do cliente quanto o do servidor
sao privados/loopback. Headers enviados pelo cliente e X-Forwarded-Proto nao
liberam essa excecao. Nesse modo, credenciais de login e audio circulam sem
criptografia dentro da rede; usar somente em uma rede local confiavel.
A chamada do PHP para a OpenAI sempre usa HTTPS com verificacao do certificado.

Em `C:/Projetos/Servidor/nginx/conf/nginx.conf`, a localizacao exclusiva para
`api_restaurantes_venda/api1/voz/(sessao|pedido|clientes).php` define o parametro
FastCGI `GARCOM_VOZ_HTTP_LOCAL 1`. Essa localizacao tambem desativa cache e
repeticao automatica de requisicoes. Ela precisa estar carregada no Nginx.

Validar e recarregar em um PowerShell com permissao de administrador:

```powershell
& C:/Projetos/Servidor/nginx/nginx.exe -t -p C:/Projetos/Servidor/nginx/
& C:/Projetos/Servidor/nginx/nginx.exe -s reload -p C:/Projetos/Servidor/nginx/
```

Em 13/09/2026 a validacao da configuracao passou, mas a recarga foi recusada
pelo Windows (`OpenEvent`, acesso negado). A ativacao depende dessa recarga ou
do reinicio administrativo do servico, alem da instalacao/reinicio do app com
o codigo Dart atualizado. Nao houve mudanca de schema nem publicacao online.

## Verificacao

Validacao em 13/09/2026: 99 testes Flutter de voz e 90 verificacoes PHP passaram;
`flutter analyze` dos arquivos Dart alterados nao apontou problemas. Todos os
arquivos PHP de voz passaram em `php -l`, e o Nginx passou em `nginx -t`.

`test/modulos/voz/configuracao_voz_test.php` usa PDO simulado para conferir
isolamento entre empresas, prioridade do painel, chave ausente, desativacao,
tokens, ambiente legado e restricoes de transporte. Executar com um temporario
isolado para nao reutilizar o segredo de uma instalacao real.
`servidor_voz_test.php` preserva os testes anteriores de contrato e limites.
Os testes Dart em `test/modulos/voz` incluem sessao, mensagens de erro, URLs,
gravacao simulada, montagem e destinos de pedidos. Nao usam a chave real,
nao consomem creditos OpenAI e nao criam pedidos no restaurante.

As mudancas devem ser entregues juntas: API PHP local, configuracao do Nginx
local e app `sistemadevenda`. O cadastro de credenciais continua no painel
`sistemarestaurante`. Substituir qualquer chave que tenha sido exposta antes
de testar uma transcricao real.
