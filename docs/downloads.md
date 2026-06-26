---
title: Downloads de PDF e XML no SDK Ruby da NFE.io
sidebar_label: Downloads
sidebar_position: 7
slug: downloads
description: Baixe PDF/XML das notas. A maioria dos recursos devolve bytes binários (ASCII-8BIT) para salvar com File.binwrite; product_invoices devolve um Nfe::NfeFileResource com a URI do arquivo.
---

# Downloads

Os recursos de nota expõem métodos para baixar PDF e XML. Há **dois contratos de
retorno distintos** — leia esta página com atenção antes de salvar o arquivo.

## Contrato 1: bytes binários (a maioria dos recursos)

Os métodos de download de `service_invoices`, `consumer_invoices`,
`transportation_invoices`, `inbound_product_invoices`, além de
`product_invoice_query` e `consumer_invoice_query`, retornam uma **String
binária** (encoding `ASCII-8BIT`). Salve sempre com `File.binwrite` para não
corromper o conteúdo:

```ruby
pdf_bytes = client.service_invoices.download_pdf(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  invoice_id: "abc-123"
)

File.binwrite("nota.pdf", pdf_bytes)
```

O mesmo vale para o XML:

```ruby
xml_bytes = client.service_invoices.download_xml(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  invoice_id: "abc-123"
)

File.binwrite("nota.xml", xml_bytes)
```

:::tip ZIP de toda a empresa
Em `service_invoices`, omitir `invoice_id:` (ou passar `nil`) baixa o **ZIP** com
os documentos da empresa em vez de um único arquivo. O retorno continua sendo
bytes binários.
:::

## Contrato 2: `Nfe::NfeFileResource` (product invoices)

:::warning Exceção importante
Os métodos `download_*` de `product_invoices` e `product_invoices_rtc` **NÃO**
retornam bytes. Eles retornam um `Nfe::NfeFileResource` — um objeto de valor que
carrega a **URI** do arquivo, porque o host `api.nfse.io/v2` responde com um
envelope JSON `{ uri }`, e não com o arquivo em si.
:::

`Nfe::NfeFileResource` expõe `#uri`, `#name`, `#content_type` e `#size`. Para
obter os bytes, faça o download da `uri` separadamente:

```ruby
file = client.product_invoices.download_pdf(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  invoice_id: "abc-123"
)

file.uri          # ex.: "https://.../danfe.pdf"
file.content_type # ex.: "application/pdf"

require "open-uri"
File.binwrite("danfe.pdf", URI.open(file.uri).read)
```

Os demais downloads de `product_invoices` seguem o mesmo contrato e também
devolvem um `Nfe::NfeFileResource`: `download_xml`, `download_rejection_xml`,
`download_epec_xml`, `download_correction_letter_pdf` e
`download_correction_letter_xml`.

## Resumo dos contratos

| Recurso | Retorno do `download_*` | Como salvar |
| --- | --- | --- |
| `service_invoices` | String binária (`ASCII-8BIT`) | `File.binwrite` direto |
| `consumer_invoices` | String binária | `File.binwrite` direto |
| `transportation_invoices` | String binária | `File.binwrite` direto |
| `inbound_product_invoices` | String binária | `File.binwrite` direto |
| `product_invoice_query` | String binária | `File.binwrite` direto |
| `consumer_invoice_query` | String binária | `File.binwrite` direto |
| `product_invoices` | `Nfe::NfeFileResource` (URI) | baixe a `#uri` e então `File.binwrite` |
| `product_invoices_rtc` | `Nfe::NfeFileResource` (URI) | baixe a `#uri` e então `File.binwrite` |

## Próximos passos

- [Roteamento multi-host](./multi-host-routing.md) — por que os dois contratos existem (hosts diferentes).
- [Emissão RTC](./rtc-emission.md) — NF-e/NFC-e e NFS-e da Reforma Tributária.
- [Paginação](./pagination.md) — liste notas antes de baixá-las.
