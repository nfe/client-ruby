# Manutenção da documentação (interno)

> Documento **interno** do repositório (não é uma página do Docusaurus — não tem
> frontmatter e não deve ser copiado para o `nfeio-docs`).

Esta pasta `docs/` é a **residência canônica** da documentação do SDK Ruby. Os
arquivos já vêm com o frontmatter e as convenções do **Docusaurus 3** para um
`copy/paste` direto na documentação oficial (`nfeio-docs`).

## Estrutura

| Caminho | Papel |
|---|---|
| `docs/README.md` | Página de entrada (landing). Frontmatter `layout_type: IntegrationLayout`, espelhando `bibliotecas/php.md`. |
| `docs/*.md` | Guias temáticos (configuração, 202/polling, erros, webhooks, paginação, downloads, multi-host, RTC). |
| `docs/resources/*.md` | Cookbook — uma página por recurso (17 canônicos + RTC). |
| `docs/_category_.json`, `docs/resources/_category_.json` | Categorias da sidebar do Docusaurus. |
| `docs/api/` | Referência da API gerada pelo YARD (HTML). **Gitignorada** — gere com `rake doc`. |
| `docs/yard-theme/` | Tema YARD com a identidade NFE.io (CSS + `headers.erb` + `setup.rb`). Versionado. |

## Gerar a referência da API (YARD)

```sh
bundle exec rake doc
```

Saída em `docs/api/` (122+ páginas HTML, tema NFE.io). É **self-contained**
(logos em data-URI), então a pasta funciona em qualquer lugar.

## Sincronizar com o `nfeio-docs` (Docusaurus 3.8)

O destino principal destes arquivos é o `nfeio-docs`. Enquanto não há automação,
o fluxo é manual:

1. **Guias + cookbook** → copie `docs/*.md` e `docs/resources/` para
   `docs/docs/desenvolvedores/bibliotecas/ruby/` no `nfeio-docs`. Renomeie
   `README.md` para `index.md` (ou `ruby.md`) — o frontmatter `IntegrationLayout`
   já está pronto. Adicione o `heroImage` `static/img/bibliotecas/ruby.svg`.
2. **Referência da API** → rode `rake doc` e copie `docs/api/` para
   `static/api/ruby/` no `nfeio-docs`. O link na landing (`/api/ruby/`) já aponta
   para lá.
3. Revise a sidebar — os `_category_.json` e os `sidebar_position` já definem a
   ordem.

## Convenções ao editar (mantêm o copy/paste sem retrabalho)

- **Frontmatter** em toda página: `title`, `sidebar_label`, `sidebar_position`,
  `description` (a landing usa o bloco `IntegrationLayout`).
- **MDX-safe** (Docusaurus 3 lê `.md` como MDX): todo código em blocos cercados
  (` ```ruby `, ` ```sh `) ou crase inline; **nunca** `<` ou `{` soltos na prosa.
- **Callouts** como admonitions do Docusaurus: `:::note`, `:::tip`, `:::warning`.
- **Links** relativos entre páginas: `./outra.md`, `../guia.md`.
- **Precisão**: nomes de método/kwargs vêm do código (`lib/nfe/resources/`).
  Nada de método inventado.
