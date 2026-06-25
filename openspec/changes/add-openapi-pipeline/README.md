# add-openapi-pipeline

Pipeline de codegen Ruby (stdlib + dev-only) que lê os specs OpenAPI sincronizados do nfeio-docs e emite value objects `Data.define` imutáveis em `lib/nfe/generated/` mais assinaturas `.rbs` em `sig/nfe/generated/`, com banner anti-edição, validação de spec e guarda de sincronia em CI (`rake generate` / `generate:check`).
