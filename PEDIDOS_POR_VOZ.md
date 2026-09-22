# Pedidos por voz

> Atualização de 22/09/2026: o pedido atual usa o protocolo 2, com vários itens,
> correção e confirmação no carrinho, incluindo Delivery e Balcão. O modo local
> Whisper.cpp + Ollama é configurado em Integrações > Comanda Eletrônica e por Voz.
> Consulte [a documentação atual](docs/PEDIDOS_POR_VOZ.md). As notas abaixo
> descrevem o protocolo 1 preservado para compatibilidade; o cardápio e o carrinho
> não usam mais seu envio automático por voz.

## O que foi implementado

- Microfone ao lado dos favoritos no cardapio.
- Microfone a direita do QR Code nas listas de mesas e comandas.
- Gravacao iniciada pelo garcom e encerrada em "Concluir pedido".
- Uma pizza ou um produto simples por comando. Pizza inclui tamanho, sabores,
  bordas, adicionais e observacao. O calculo usa as regras existentes do app.
- "Adicionar no carrinho" guarda o produto no atendimento atual, preserva os
  rascunhos anteriores e nao envia para preparo. Sem destino falado, fica no carrinho.
- "Enviar para a cozinha" usa a mesma fila duravel de pedidos e preparo.
  Apenas nesse destino o carrinho precisa estar vazio, para nao enviar outros
  rascunhos sem autorizacao. Destinos contraditorios pedem esclarecimento.
- Nomes ambiguos, opcoes indisponiveis, limites excedidos e escolhas obrigatorias
  interrompem o envio. Montagens especiais (kits, acai e acompanhamentos) continuam
  no configurador manual nesta etapa. Nao ha transferencia por voz.
- Pausar/sair do app durante a gravacao ou interpretacao cancela o comando.
  Gravar mais de 60 segundos cancela, sem enviar uma fala cortada.

## Ativacao obrigatoria

### Abertura de mesas e comandas

- "Abrir comanda 3 com o nome de Bruno Masson": abre a comanda e grava
  `Bruno Masson` na observacao, sem criar ou selecionar cadastro de cliente.
- "Abrir comanda 3 vinculada a mesa 2 com o nome de Bruno Masson": adiciona
  o vinculo com a mesa 2. A mesa precisa estar disponivel pelas regras existentes.
- "Abrir mesa 3 com o nome de Bruno Masson": salva o nome na observacao.
- "Abrir comanda 3 e selecionar o cliente cadastrado Bruno Masson": consulta
  exatamente o nome completo (nome ou razao social) na empresa autenticada.
  Clientes inativos, inexistentes e homonimos bloqueiam a abertura automatica.

O comando termina em "Concluir e abrir". O numero falado corresponde ao nome
visivel da mesa/comanda, nao ao ID do banco ou codigo QR. Uma mesa nao vincula
outra mesa. O recurso so abre atendimentos livres, nao edita ou reabre contas
ocupadas. A abertura segue a fila existente com verificacao de versao e sem
fallback para o endpoint legado. O aviso de abertura salva nao confirma que o
servidor ja aceitou a operacao; conferir eventuais pendencias/conflitos.
Nome/observacao respeitam os 100 caracteres da coluna atual; comandos maiores
sao rejeitados, sem truncar o texto.

Publicar tambem `voz/abertura.php` e `voz/clientes.php`, junto com as alteracoes
de `voz/pedido.php` e `voz/interpretacao.php`. O app verifica `abertura_voz: 1`
antes de gravar. Nenhuma tabela ou coluna nova e necessaria.

Pedidos de produtos verificam `destino_voz: 1` e enviam o mesmo marcador no
multipart. Publicar app e API atualizados: a API rejeita pedidos de versoes antigas
que ignoravam o destino falado. O contrato usa a saida estruturada da OpenAI;
respostas incompletas ou destinos desconhecidos nao autorizam envio.

### Microfone e erros de inicializacao

- O toque mostra estado ocupado, mesmo durante atualizacao do cardapio.
- O gravador nativo so e criado ao iniciar a gravacao, dentro do tratamento de
  erros. Falta do plugin exige nova instalacao completa, nao apenas hot reload.
- Negar permissao ou faltar configuracao da API mostra erro e permite fechar
  a janela, sem descartar o carrinho ou enviar pedidos.
- A verificacao HTTPS tem timeout curto; o prazo maior fica reservado ao audio.

### Configuracao do servidor

A assinatura do ChatGPT/Codex nao substitui a chave da API. Nao inserir tokens de
login do ChatGPT, arquivos de autenticacao do Codex ou a chave OpenAI no app.

1. Criar um projeto e uma chave da API OpenAI com faturamento disponivel.
2. Publicar pelo Git a pasta `api_restaurantes_venda/api1/voz/` do repositorio
   `sistema/apis_restaurantes`. O codigo nao altera o banco de dados.
3. Configurar as variaveis de ambiente do processo PHP, fora do Git e da pasta
   publica. Elas precisam estar disponiveis para `getenv` no Apache/PHP-FPM:

| Variavel | Valor |
| --- | --- |
| `OPENAI_API_KEY` | Chave do projeto OpenAI |
| `GARCOM_VOZ_SEGREDO` | Segredo aleatorio exclusivo, no minimo 32 caracteres |
| `GARCOM_VOZ_EMPRESAS` | IDs das empresas autorizadas, separados por virgula |
| `GARCOM_VOZ_MODELO` | Opcional: `gpt-4.1-mini` |
| `GARCOM_VOZ_TRANSCRICAO` | Opcional: `gpt-4o-mini-transcribe` |

4. Habilitar HTTPS com certificado confiavel no mesmo servidor da API. Para uma
   conexao local HTTP, somente a voz usa o mesmo host/caminho por HTTPS na porta
   443. Nao ha fallback para HTTP nem desativacao da validacao de certificado.
   Em proxy reverso, configurar HTTPS no ambiente PHP pelo proxy confiavel; nao
   confiar em cabecalhos enviados livremente pelo cliente.
5. Habilitar cURL e permitir a saida HTTPS do servidor para `api.openai.com`.
   Ajustar `upload_max_filesize` para ao menos 1M, `post_max_size` para ao menos 2M
   e os timeouts PHP/proxy para mais de 90 segundos.
6. Gerar uma nova versao Android/iOS para incluir a permissao e o plugin do
   microfone. Hot reload nao instala plugins nativos.

O modo online usa `api6`, cuja implementacao nao esta neste workspace. Esse
ambiente exige a mesma integracao adaptada a sua autenticacao antes de ativar voz.

## Seguranca e operacao

- A sessao de voz autentica o usuario ativo da empresa via HTTPS usando a
  credencial do login existente. Seu token assinado dura 12 horas, fica apenas
  na memoria da janela de voz e nunca permite escolher outra empresa.
- Limites: 6 pedidos/minuto e 200/dia por usuario; 30/minuto e 1000/dia por
  empresa. Contadores em arquivos privados com `flock`, por instancia de API.
  Em varios servidores, usar um limitador compartilhado antes de expandir.
- Configure tambem os controles de uso/faturamento no projeto OpenAI. Os limites
  locais sao por requisicao, nao um teto financeiro garantido.
- Audio temporario removido ao fechar a janela. O servidor usa o upload temporario
  do PHP. Nao ha log de audio, transcricao ou segredo nesta integracao. A requisicao
  Responses usa `store: false`; isso nao equivale a prometer retencao zero do provedor.
- Sem API, sem internet do servidor ou sem HTTPS, o pedido manual permanece
  disponivel. A interpretacao de voz nao funciona offline.
- Depois de preparado, o pedido segue a sincronizacao existente. Pedido salvo no
  aparelho nao equivale a comprovante fisicamente impresso. Conferir as pendencias
  de sincronizacao e impressao se a conexao cair.

## Validacao antes de liberar ao restaurante

Testes automatizados usam respostas simuladas, sem cobranca nem vendas reais.
A chave nao estava disponivel durante a implementacao. Ainda e necessario validar
microfone no Android/iPhone, reconhecimento no ruido real do salao e impressao
fisica num ambiente de homologacao, com a API configurada. O audio de exemplo
anexado nao foi transcrito pela OpenAI; os testes usam o exemplo escrito.

Validacao leve do contrato de abertura, sem Flutter nem chamadas externas:
`dart test/modulos/voz/contrato_abertura_check.dart`.
Em 13/09/2026 passaram 149 testes Flutter focados em voz, conexao, carrinho,
catalogo, sincronizacao, preparo e abertura, com `--no-pub --no-test-assets
--concurrency=1`. Passaram tambem 45 verificacoes PHP do contrato da API.
Os testes de microfone incluem plugin ausente, permissao negada, cancelamento e
toque no cardapio com carrinho cheio. Nao substituem a homologacao no aparelho.

A compilacao `flutter build ios --debug --no-pub --no-codesign` terminou com
sucesso. O `Runner.app` gerado contem `NSMicrophoneUsageDescription` e
`record_ios.framework`; o build anterior nao continha a descricao de permissao.
Esse artefato de validacao nao esta assinado nem foi instalado no iPhone. Executar
novamente pelo fluxo normal de assinatura/instalacao do projeto, sem desinstalar
o aplicativo nem apagar seus dados, para preservar pedidos locais pendentes.

Casos de homologacao: pizza G Mussarela/Calabresa com borda Chocolate e Milho;
variacao de nomes e sotaques; pausa na fala; duas pizzas iguais; produto inexistente;
cancelar; negar microfone; fechar/reutilizar comanda em outro terminal; queda de
conexao depois do envio; papel/impressora indisponivel. Nao liberar envio automatico
em producao antes de validar estes cenarios e a qualidade da interpretacao.

Referencias: [autenticacao OpenAI](https://developers.openai.com/api/reference/overview#authentication),
[transcricao](https://developers.openai.com/api/docs/guides/speech-to-text),
[saida estruturada](https://developers.openai.com/api/docs/guides/structured-outputs),
[plugin record](https://pub.dev/packages/record).
