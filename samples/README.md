# Exemplos do SDK Ruby da NFE.io

Scripts executáveis que demonstram a gem `nfe-io` (v1) ponta a ponta. Cada
arquivo é independente: carrega `config.rb`, lê variáveis de ambiente e usa o
cliente global `$nfe`.

## Configuração

1. Copie o template de variáveis e preencha:

   ```sh
   cp samples/.env.example samples/.env
   $EDITOR samples/.env
   ```

   `samples/.env` é ignorado pelo Git. Alternativamente, exporte as variáveis
   direto no shell:

   ```sh
   export NFE_API_KEY="sua-chave"
   export NFE_DATA_API_KEY="sua-chave-de-dados"   # opcional
   export NFE_COMPANY_ID="id-da-empresa"
   export NFE_WEBHOOK_SECRET="segredo-do-webhook" # apenas webhook_verify.rb
   ```

2. Rode qualquer exemplo a partir da raiz do repositório:

   ```sh
   ruby samples/<arquivo>.rb
   ```

`config.rb` prefere a gem instalada (`gem install nfe-io`) e cai para a
`lib/` do repositório quando rodando a partir do checkout — não é preciso
instalar a gem para experimentar.

## Variáveis de ambiente

| Variável             | Obrigatória | Usada por                                   |
| -------------------- | ----------- | ------------------------------------------- |
| `NFE_API_KEY`        | sim         | todos os exemplos                           |
| `NFE_DATA_API_KEY`   | não         | consultas (CEP/CNPJ/CPF); cai para a principal |
| `NFE_COMPANY_ID`     | depende     | emissão e CRUD de empresa/pessoas           |
| `NFE_WEBHOOK_SECRET` | depende     | `webhook_verify.rb`                         |

> Use sempre uma conta/empresa de **testes**. Alguns exemplos criam e removem
> recursos (ex.: `company_crud.rb`) ou emitem documentos fiscais.

## Exemplos

| Arquivo                      | O que demonstra                                                        |
| ---------------------------- | ---------------------------------------------------------------------- |
| `service_invoice_issue.rb`   | NFS-e: emissão + polling manual (`FlowStatus.terminal?`) + PDF binário |
| `product_invoice_issue.rb`   | NF-e: emissão assíncrona (conclusão via webhook)                       |
| `consumer_invoice_issue.rb`  | NFC-e: emissão com resultado discriminado (pendente x emitida)         |
| `rtc_service_invoice.rb`     | NFS-e RTC: emissão com grupo `ibsCbs` + polling                        |
| `company_crud.rb`            | Empresa: create + list + retrieve + update + remove                    |
| `legal_person_create.rb`     | Pessoa jurídica: criação                                               |
| `legal_person_update.rb`     | Pessoa jurídica: atualização                                           |
| `webhook_verify.rb`          | Verificação de assinatura de webhook (HMAC-SHA1, bytes brutos)         |
| `cnpj_lookup.rb`             | Consulta de CNPJ: dados básicos + inscrição estadual para emissão      |
| `cpf_lookup.rb`              | Consulta de CPF: situação cadastral                                    |
| `cep_lookup.rb`              | Consulta de CEP                                                        |
| `tax_calculation.rb`         | Motor de cálculo de impostos por tenant                                |

## Notas

- A emissão é **assíncrona** (HTTP 202). Não há `create_and_wait`/`create_batch`
  na v1.x — faça polling chamando `retrieve` em laço até
  `Nfe::FlowStatus.terminal?(invoice.flow_status)` (estados terminais:
  `Issued`, `IssueFailed`, `Cancelled`, `CancelFailed`).
- Downloads de NFS-e/NFC-e retornam **bytes** (`ASCII-8BIT`) — grave com
  `File.binwrite`. Já os downloads de **NF-e** retornam um
  `Nfe::NfeFileResource` (objeto com a URI do arquivo), não os bytes.
- Webhooks: passe sempre os **bytes brutos** do corpo (antes de parsear JSON).
  A assinatura prova autenticidade, não atualidade — handlers devem ser
  idempotentes e deduplicar pelo id do evento/nota.
