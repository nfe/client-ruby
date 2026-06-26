---
title: Paginação de listas no SDK Ruby da NFE.io
sidebar_label: Paginação
sidebar_position: 6
slug: paginacao
description: Itere listas com Nfe::ListResponse (que inclui Enumerable) e leia os metadados de página em Nfe::ListPage — paginação por página ou por cursor, conforme o recurso.
---

# Paginação

Os métodos `list` retornam um `Nfe::ListResponse`. Ele inclui `Enumerable`, então
você itera diretamente sobre os itens hidratados — sem precisar acessar `#data` —
e lê os metadados de paginação em `#page`.

## `Nfe::ListResponse`

Tem dois membros:

- `#data` — o `Array` de DTOs hidratados.
- `#page` — um `Nfe::ListPage` com os metadados de paginação.

Como inclui `Enumerable` (delegando `each` a `#data`), você usa `map`, `select`,
`each_with_index` e os demais métodos diretamente:

```ruby
list = client.service_invoices.list(company_id: "55df4dc6b6cd9007e4f13ee8")

list.each do |invoice|
  puts invoice.id
end

ids = list.map(&:id)   # Enumerable direto, sem list.data
total = list.count
```

## `Nfe::ListPage`

Os endpoints da NFE.io paginam em **uma de duas formas**, e cada recurso
preenche apenas a metade relevante:

- **Por página** — `#page_index` / `#page_count` (campos de cursor ficam `nil`).
- **Por cursor** — `#starting_after` / `#ending_before` (`#page_index` fica `nil`).

`#total` é opcional e pode aparecer em qualquer uma das formas.

```ruby
page = list.page

if page.page_index
  puts "Página #{page.page_index} de #{page.page_count}"
else
  puts "Próximo cursor: #{page.starting_after}"
end

page.total # pode ser nil
```

## Qual recurso usa qual forma

| Recurso | Forma de paginação |
| --- | --- |
| `service_invoices.list` | por página (`page_index`/`page_count`) |
| `product_invoices.list` | por cursor (`starting_after`/`ending_before`) |
| `product_invoices_rtc.list` | por cursor |
| `consumer_invoices.list` | por cursor |
| `state_taxes.list` | por cursor |

### Por página: `service_invoices`

```ruby
list = client.service_invoices.list(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  page_index: 1,
  page_count: 50
)

list.each { |inv| puts inv.id }
```

### Por cursor: `product_invoices`

:::warning `environment:` é obrigatório
`product_invoices.list` e `product_invoices_rtc.list` **exigem** o argumento
`environment:` — uma String `"Production"` ou `"Test"`. Omiti-lo levanta
`Nfe::InvalidRequestError`.
:::

```ruby
list = client.product_invoices.list(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  environment: "Production",
  limit: 50
)

# Avance usando o cursor da página anterior:
next_page = client.product_invoices.list(
  company_id: "55df4dc6b6cd9007e4f13ee8",
  environment: "Production",
  starting_after: list.page.starting_after,
  limit: 50
)
```

## Próximos passos

- [Downloads](./downloads.md) — baixe os arquivos das notas listadas.
- [Webhooks](./webhooks.md) — receba eventos por push em vez de listar.
- [Roteamento multi-host](./multi-host-routing.md) — entenda em qual host cada recurso vive.
