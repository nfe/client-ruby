---
title: Configuração do cliente do SDK Ruby da NFE.io
sidebar_label: Configuração
sidebar_position: 2
slug: configuracao
description: Todas as opções do Nfe::Client e do Nfe::Configuration — chaves de API, timeouts, retries, modelo de duas chaves, sandbox vs. produção, TLS e proxy.
---

# Configuração

Esta página descreve como configurar o `Nfe::Client`: os argumentos aceitos
diretamente no construtor, as opções avançadas que vivem em `Nfe::Configuration`,
o fallback por variáveis de ambiente, o modelo de duas chaves e as configurações
de rede (TLS e proxy).

## Argumentos de `Nfe::Client.new`

O construtor aceita um conjunto enxuto de opções de conveniência:

```ruby
client = Nfe::Client.new(
  api_key: ENV.fetch("NFE_API_KEY"),
  data_api_key: nil,
  configuration: nil,
  environment: :production,
  timeout: 30,
  max_retries: 3,
  logger: nil,
  user_agent_suffix: nil
)
```

| Argumento | Tipo | Padrão | Descrição |
| --- | --- | --- | --- |
| `api_key` | `String`, `nil` | `nil` | Chave principal. Cai para `NFE_API_KEY` quando ausente. |
| `data_api_key` | `String`, `nil` | `nil` | Chave dos serviços de dados. Cai para `NFE_DATA_API_KEY`. |
| `configuration` | `Nfe::Configuration`, `nil` | `nil` | Quando informado, **os demais argumentos de conveniência são ignorados**. |
| `environment` | `Symbol` | `:production` | `:production` ou `:development`. Reservado para uso futuro (sem efeito hoje). |
| `timeout` | `Integer` | `30` | Timeout de leitura em segundos (deve ser positivo). |
| `max_retries` | `Integer` | `3` | Orçamento de retentativas (inteiro não negativo). |
| `logger` | objeto, `nil` | `nil` | Logger opcional (responde a `info`/`warn`/`error`). |
| `user_agent_suffix` | `String`, `nil` | `nil` | Sufixo anexado ao `User-Agent` do SDK. |

:::note Validação na construção
As opções são validadas na criação. Valores inválidos (por exemplo, `timeout`
não positivo, `max_retries` negativo ou `environment` desconhecido) levantam
`Nfe::ConfigurationError` antes de qualquer requisição HTTP. Veja
[Tratamento de erros](./errors.md).
:::

## Opções avançadas — somente em `Nfe::Configuration`

Algumas opções **não** são aceitas diretamente por `Nfe::Client.new`. Elas vivem
em `Nfe::Configuration` e são injetadas via `configuration:`:

| Opção | Tipo | Padrão | Descrição |
| --- | --- | --- | --- |
| `open_timeout` | `Integer` | `10` | Timeout de conexão em segundos (deve ser positivo). |
| `base_url_overrides` | `Hash{Symbol=>String}` | `{}` | Sobrescreve o host por família (escape hatch). |
| `ca_file` | `String`, `nil` | `nil` | Caminho de um bundle de CA a **adicionar** ao trust store. |
| `ca_path` | `String`, `nil` | `nil` | Diretório de certificados de CA a **adicionar** ao trust store. |
| `proxy` | `String`, `URI`, `nil` | `nil` | Repassado ao `Net::HTTP`. |

Para usá-las, construa um `Nfe::Configuration` e passe-o ao cliente. Note que ao
informar `configuration:`, os argumentos de conveniência (como `api_key:` ou
`timeout:`) passados ao `Client.new` são ignorados — tudo deve estar na
configuração:

```ruby
configuration = Nfe::Configuration.new(
  api_key: ENV.fetch("NFE_API_KEY"),
  data_api_key: ENV.fetch("NFE_DATA_API_KEY", nil),
  timeout: 60,
  open_timeout: 15,
  max_retries: 5,
  proxy: "http://proxy.interno:3128",
  ca_file: "/etc/ssl/certs/corporate-ca.pem"
)

client = Nfe::Client.new(configuration: configuration)
```

:::tip Quando preciso de `Nfe::Configuration`?
Para o caso comum, basta `Nfe::Client.new(api_key: "...")`. Use a configuração
explícita quando precisar de `open_timeout`, `proxy`, `ca_file`/`ca_path` ou
`base_url_overrides`.
:::

## Fallback por variáveis de ambiente

As chaves resolvem nesta ordem de precedência: **argumento explícito não vazio
vence**; caso contrário, a variável de ambiente (quando presente) é adotada.

- `api_key` cai para `NFE_API_KEY`.
- `data_api_key` cai para `NFE_DATA_API_KEY`.

```sh
export NFE_API_KEY="sua-chave-principal"
export NFE_DATA_API_KEY="sua-chave-de-dados"
```

```ruby
# Sem argumentos: ambas as chaves vêm do ambiente.
client = Nfe::Client.new
```

:::note Pelo menos uma chave
A validação "ao menos uma chave informada" roda **após** o fallback. Se nenhuma
chave for resolvida (nem por argumento, nem por ambiente), a construção levanta
`Nfe::ConfigurationError`. Um cliente apenas com `data_api_key` é válido — a
exigência da chave principal é adiada até que um recurso da família `main` seja
acessado.
:::

## Modelo de duas chaves

O SDK usa duas chaves. As famílias de **dados** — `addresses` (CEP),
`legal_entity` (CNPJ), `natural_person` (CPF) e `nfe_query` (consultas) — usam a
`data_api_key` quando presente, com **fallback** para a `api_key`. Todas as
demais famílias usam a `api_key`.

```ruby
# Cliente com as duas chaves:
client = Nfe::Client.new(
  api_key: "chave-de-emissao",
  data_api_key: "chave-de-consulta"
)

# - client.addresses          → usa data_api_key (família de dados)
# - client.legal_entity_lookup → usa data_api_key
# - client.service_invoices    → usa api_key (emissão)
# - client.companies           → usa api_key
```

Quando nenhuma chave resolve para a família acessada, o SDK levanta
`Nfe::ConfigurationError` no momento da requisição.

:::note CT-e usa a chave principal
A família `cte` (`api.nfse.io` — emissão de NF-e/NFC-e/CT-e e regras tributárias)
**não** é uma família de dados: usa a `api_key`. Emissão é capacidade central,
não consulta de dados.
:::

## Sandbox vs. Produção

:::warning A separação produção vs. teste fica na conta, não no SDK
A escolha entre **produção** e **teste (homologação)** é definida na configuração
da sua conta em [app.nfe.io](https://app.nfe.io) (lado servidor) — **não** pela
chave de API nem pelo SDK. Não existe "URL de sandbox": produção e desenvolvimento
apontam para os mesmos endpoints.
:::

O argumento `environment:` do cliente (`:production` / `:development`) está
**reservado para uso futuro**: ele é validado, mas hoje **não tem efeito** sobre
endpoints, chaves ou comportamento. Suporte completo a `environment:` está
planejado para uma versão futura.

:::note Ambiente SEFAZ é outra coisa
Os recursos de produto e consumidor (NF-e/NFC-e) aceitam um parâmetro
**separado** `environment:` do tipo `String` (`"Production"` / `"Test"`) nas
operações de listagem e emissão — esse é o ambiente da SEFAZ e é tratado nos
guias daqueles recursos, não aqui.
:::

## TLS e proxy

### TLS — confiança só pode ser adicionada

`ca_file` (e, opcionalmente, `ca_path`) é o **único** override do trust store de
TLS e só pode **adicionar/substituir** o bundle de CA usado para verificar o par.
A verificação completa do certificado do servidor permanece ativa em toda
requisição.

```ruby
configuration = Nfe::Configuration.new(
  api_key: ENV.fetch("NFE_API_KEY"),
  ca_file: "/etc/ssl/certs/corporate-ca.pem"
)
```

:::warning Não há como desabilitar a verificação
Por design, **não existe** API pública para desabilitar a verificação do par
(sem `VERIFY_NONE`, sem `insecure_ssl`). O atributo `insecureSsl` que você possa
ver na API é uma propriedade do **alvo de entrega de webhook** (lado servidor) e
não tem relação com a configuração de TLS de saída do SDK.
:::

### Proxy

Defina `proxy` em `Nfe::Configuration` para repassá-lo ao `Net::HTTP`:

```ruby
configuration = Nfe::Configuration.new(
  api_key: ENV.fetch("NFE_API_KEY"),
  proxy: "http://usuario:senha@proxy.interno:3128"
)
```

## Próximos passos

- [Emissão assíncrona e polling](./async-and-polling.md) — o contrato HTTP 202.
- [Tratamento de erros](./errors.md) — `rescue` por tipo.
- [Primeiros passos](./getting-started.md) — instalação e primeira emissão.
