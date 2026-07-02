# frozen_string_literal: true

# Smoke test READ-ONLY contra a API real (sandbox).
# NÃO emite, cancela ou grava nada — só consultas/listagens.
#
# Valida, contra respostas reais: autenticação, roteamento multi-host, o modelo
# de duas chaves e o mapeamento dos DTOs corrigidos na revisão (Address#district,
# LegalEntity#status_on/#size, etc.).
#
#   1) preencha samples/.env   2) ruby samples/smoke_readonly.rb

require_relative "config"

PASS = []
FAIL = []

def check(label)
  result = yield
  puts "  \e[32m✓\e[0m #{label}"
  puts "      #{result}" if result && !result.to_s.empty?
  PASS << label
rescue StandardError => e
  puts "  \e[31m✗\e[0m #{label}"
  puts "      #{e.class}: #{e.message.to_s[0, 160]}"
  FAIL << label
end

def short(obj, max = 260)
  obj.inspect[0, max]
end

def count(result)
  return result.data.size if result.respond_to?(:data)

  result.respond_to?(:size) ? result.size : "?"
end

puts "Smoke test READ-ONLY — sandbox — nfe-io #{Nfe::VERSION} (não grava nada)"
puts

check("addresses.lookup_by_postal_code('01310100')  [DTO Address: district/city]") do
  short($nfe.addresses.lookup_by_postal_code("01310100").addresses.first)
end

check("tax_codes.list_operation_codes  [:cte, page-style]") do
  r = $nfe.tax_codes.list_operation_codes
  "itens=#{r.items.size}  current_page=#{r.current_page}  total_pages=#{r.total_pages}"
end

check("companies.list  [:main, DTO Company]") do
  "data=#{count($nfe.companies.list(page_count: 5))}"
end

cnpj = ENV["NFE_TEST_CNPJ"].to_s.strip
cnpj = "00000000000191" if cnpj.empty? # Banco do Brasil (público)
check("legal_entity_lookup.get_basic_info('#{cnpj}')  [DTO LegalEntity: status_on/size]") do
  short($nfe.legal_entity_lookup.get_basic_info(cnpj).legal_entity)
end

if $company_id.to_s.strip.empty?
  puts "  \e[33m–\e[0m list NFS-e/NF-e: pulado (defina NFE_COMPANY_ID no samples/.env)"
else
  check("service_invoices.list(company_id)  [page-style]") do
    r = $nfe.service_invoices.list(company_id: $company_id)
    "data=#{r.data.size}  page_index=#{r.page&.page_index}"
  end
  check("product_invoices.list(company_id, environment: 'Test')  [cursor]") do
    r = $nfe.product_invoices.list(company_id: $company_id, environment: "Test")
    "data=#{r.data.size}  starting_after=#{r.page&.starting_after.inspect}"
  end
  check("consumer_invoices.list(company_id:, environment: 'Test')  [:cte, DTO ConsumerInvoice]") do
    "data=#{count($nfe.consumer_invoices.list(company_id: $company_id, environment: 'Test'))}"
  end
  check("state_taxes.list(company_id)  [:cte, DTO NfeStateTax]") do
    "data=#{count($nfe.state_taxes.list($company_id))}"
  end
  check("companies.retrieve(company_id)  [DTO Company]") do
    short($nfe.companies.retrieve($company_id))
  end
  check("legal_people.list(company_id)  [DTO LegalPerson]") do
    "data=#{count($nfe.legal_people.list($company_id))}"
  end
  check("natural_people.list(company_id)  [DTO NaturalPerson]") do
    "data=#{count($nfe.natural_people.list($company_id))}"
  end
end

puts
puts "Resumo: #{PASS.size} OK, #{FAIL.size} falha(s)"
exit(FAIL.empty? ? 0 : 1)
