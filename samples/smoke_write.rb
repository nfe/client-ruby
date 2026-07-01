# frozen_string_literal: true

# Smoke test de ESCRITA contra a API real (sandbox).
#
# Dois blocos:
#
#   A) Caminhos de erro — NÃO gravam nada. Validam, contra respostas reais, o
#      mapeamento de exceções do SDK: 401 -> AuthenticationError,
#      404 -> NotFoundError, 422 -> InvalidRequestError. Rodam sempre.
#
#   B) Emissão de NF-e + idempotência — GRAVAM um documento de teste
#      (environmentType: "Test"). Só rodam com a trava SMOKE_WRITE=1, para
#      evitar emissão acidental.
#
# Pré-requisitos (samples/.env):
#   NFE_API_KEY       — chave principal
#   NFE_DATA_API_KEY  — chave de dados (opcional)
#   NFE_COMPANY_ID    — empresa de teste habilitada para NF-e (host api.nfse.io)
#
# Uso:
#   ruby samples/smoke_write.rb              # só os caminhos de erro
#   SMOKE_WRITE=1 ruby samples/smoke_write.rb  # + emissão de NF-e de teste
#
# Payload da NF-e: usa um exemplo embutido (mesmo de product_invoice_issue.rb).
# Para usar o seu, aponte NFE_NFE_PAYLOAD para um arquivo .json em camelCase.

require_relative "config"
require "json"
require "securerandom"

PASS = []
FAIL = []

# Executa o bloco e considera OK se NÃO levantar erro.
def check(label)
  result = yield
  puts "  \e[32m✓\e[0m #{label}"
  puts "      #{result}" if result && !result.to_s.empty?
  PASS << label
rescue StandardError => e
  puts "  \e[31m✗\e[0m #{label}"
  puts "      #{e.class}: #{e.message.to_s[0, 200]}"
  FAIL << label
end

# Considera OK quando o bloco levanta EXATAMENTE a exceção esperada (ou uma
# subclasse). Qualquer outra exceção — ou nenhuma — é falha.
def expect_error(label, klass)
  yield
  puts "  \e[31m✗\e[0m #{label}"
  puts "      não levantou erro algum (esperava #{klass})"
  FAIL << label
rescue klass => e
  detail = e.message.to_s.gsub(/\s+/, " ")[0, 160]
  puts "  \e[32m✓\e[0m #{label}"
  puts "      #{e.class}#{" — #{detail}" unless detail.empty?}"
  PASS << label
rescue StandardError => e
  puts "  \e[31m✗\e[0m #{label}"
  puts "      esperava #{klass}, veio #{e.class}: #{e.message.to_s[0, 160]}"
  FAIL << label
end

def section(title)
  puts
  puts "\e[1m#{title}\e[0m"
end

NFE_PAYLOAD = {
  id: SecureRandom.uuid,
  operationNature: "Venda de mercadoria",
  environmentType: "Test",
  buyer: {
    type: "LegalEntity",
    name: "Cliente Exemplo LTDA",
    federalTaxNumber: "11222333000181",
    email: "compras@cliente-exemplo.com.br",
    address: {
      country: "BRA", postalCode: "01310-100", street: "Avenida Paulista",
      number: "1000", district: "Bela Vista",
      city: { code: "3550308", name: "São Paulo" }, state: "SP"
    }
  },
  items: [
    {
      code: "001", description: "Produto de exemplo", ncm: "84713012",
      cfop: "5102", unit: "UN", quantity: 1.0, unitAmount: 100.0, totalAmount: 100.0
    }
  ]
}.freeze

def load_nfe_payload
  path = ENV["NFE_NFE_PAYLOAD"].to_s.strip
  return NFE_PAYLOAD if path.empty?

  JSON.parse(File.read(path), symbolize_names: true)
end

puts "Smoke test de ESCRITA — sandbox — nfe-io #{Nfe::VERSION}"

company = $company_id.to_s.strip
abort "\nDefina NFE_COMPANY_ID no samples/.env para rodar este smoke." if company.empty?

# ---------------------------------------------------------------------------
# Bloco A — caminhos de erro (não gravam nada)
# ---------------------------------------------------------------------------
section "A) Caminhos de erro (sem escrita)"

expect_error("401  chave inválida -> AuthenticationError", Nfe::AuthenticationError) do
  bad = Nfe::Client.new(api_key: "chave-invalida-#{SecureRandom.hex(4)}",
                        data_api_key: "chave-invalida-#{SecureRandom.hex(4)}")
  bad.product_invoices.list(company_id: company, environment: "Test")
end

expect_error("404  invoice inexistente -> NotFoundError", Nfe::NotFoundError) do
  $nfe.product_invoices.retrieve(company_id: company, invoice_id: "0" * 24)
end

expect_error("422  payload inválido -> InvalidRequestError", Nfe::InvalidRequestError) do
  $nfe.product_invoices.create(company_id: company, data: { environmentType: "Test" })
end

# ---------------------------------------------------------------------------
# Bloco B — emissão de NF-e + idempotência (GRAVA doc de teste)
# ---------------------------------------------------------------------------
section "B) Emissão de NF-e de teste (grava documento)"

unless ENV["SMOKE_WRITE"] == "1"
  puts "  \e[33m–\e[0m pulado: defina SMOKE_WRITE=1 para emitir (grava NF-e de teste)."
  puts
  puts "Resumo: #{PASS.size} OK, #{FAIL.size} falha(s)"
  exit(FAIL.empty? ? 0 : 1)
end

issued_invoice_id = nil
idempotency_key = "smoke-#{SecureRandom.uuid}"

check("create  NF-e (environmentType: Test) -> Pending/Issued") do
  result = $nfe.product_invoices.create(
    company_id: company, data: load_nfe_payload, idempotency_key: idempotency_key
  )
  if result.issued?
    issued_invoice_id = result.resource.id
    "Issued imediato: #{result.resource.id} (status #{result.resource.flow_status})"
  else
    issued_invoice_id = result.invoice_id
    "Pending (202): invoice_id=#{result.invoice_id}  location=#{result.location}"
  end
end

if issued_invoice_id
  check("idempotency-key reusado -> mesma NF-e (sem duplicar)") do
    again = $nfe.product_invoices.create(
      company_id: company, data: load_nfe_payload, idempotency_key: idempotency_key
    )
    repeated_id = again.issued? ? again.resource.id : again.invoice_id
    same = repeated_id == issued_invoice_id
    raise "id divergiu: #{repeated_id.inspect} != #{issued_invoice_id.inspect}" unless same

    "mesmo invoice_id=#{repeated_id}"
  end

  check("retrieve + poll até estado terminal (máx ~60s)") do
    final = nil
    20.times do
      inv = $nfe.product_invoices.retrieve(company_id: company, invoice_id: issued_invoice_id)
      final = inv.flow_status
      break if Nfe::FlowStatus.terminal?(final)

      sleep 3
    end
    "flow_status final=#{final.inspect}#{" (terminal)" if Nfe::FlowStatus.terminal?(final)}"
  end

  check("download_pdf -> NfeFileResource (URI, não bytes)") do
    res = $nfe.product_invoices.download_pdf(company_id: company, invoice_id: issued_invoice_id)
    "uri=#{res.respond_to?(:uri) ? res.uri.inspect : res.inspect[0, 120]}"
  end
end

puts
puts "Resumo: #{PASS.size} OK, #{FAIL.size} falha(s)"
exit(FAIL.empty? ? 0 : 1)
