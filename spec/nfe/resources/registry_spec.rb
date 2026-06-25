# frozen_string_literal: true

RSpec.describe "resource registry" do # rubocop:disable RSpec/DescribeClass
  subject(:client) { Nfe::Client.new(api_key: "main", data_api_key: "data") }

  # accessor => [resource class, expected host via base_url_for]
  def expected
    {
      service_invoices: [Nfe::Resources::ServiceInvoices, "https://api.nfe.io"],
      companies: [Nfe::Resources::Companies, "https://api.nfe.io"],
      legal_people: [Nfe::Resources::LegalPeople, "https://api.nfe.io"],
      natural_people: [Nfe::Resources::NaturalPeople, "https://api.nfe.io"],
      webhooks: [Nfe::Resources::Webhooks, "https://api.nfe.io"],
      product_invoices: [Nfe::Resources::ProductInvoices, "https://api.nfse.io"],
      consumer_invoices: [Nfe::Resources::ConsumerInvoices, "https://api.nfse.io"],
      transportation_invoices: [Nfe::Resources::TransportationInvoices, "https://api.nfse.io"],
      inbound_product_invoices: [Nfe::Resources::InboundProductInvoices, "https://api.nfse.io"],
      tax_calculation: [Nfe::Resources::TaxCalculation, "https://api.nfse.io"],
      tax_codes: [Nfe::Resources::TaxCodes, "https://api.nfse.io"],
      state_taxes: [Nfe::Resources::StateTaxes, "https://api.nfse.io"],
      product_invoice_query: [Nfe::Resources::ProductInvoiceQuery, "https://nfe.api.nfe.io"],
      consumer_invoice_query: [Nfe::Resources::ConsumerInvoiceQuery, "https://nfe.api.nfe.io"],
      addresses: [Nfe::Resources::Addresses, "https://address.api.nfe.io/v2"],
      legal_entity_lookup: [Nfe::Resources::LegalEntityLookup, "https://legalentity.api.nfe.io"],
      natural_person_lookup: [Nfe::Resources::NaturalPersonLookup, "https://naturalperson.api.nfe.io"]
    }
  end

  it "maps exactly seventeen accessors across six distinct hosts" do
    expect(expected.size).to eq(17)
    expect(expected.values.map(&:last).uniq.size).to eq(6)
  end

  it "returns the right class for each accessor" do
    expected.each_key do |accessor|
      klass = expected.fetch(accessor).first
      expect(client.public_send(accessor)).to be_a(klass)
    end
  end

  it "resolves each declared family to its canonical host" do
    expected.each_key do |accessor|
      host = expected.fetch(accessor).last
      family = client.public_send(accessor).send(:api_family)
      expect(client.configuration.base_url_for(family)).to eq(host)
    end
  end

  it "exposes the lookup resources as functional (non-stub) instances" do
    expect(client.addresses).to respond_to(:lookup_by_postal_code, :search, :lookup_by_term)
    expect(client.legal_entity_lookup).to respond_to(:get_basic_info, :get_state_tax_info)
    expect(client.natural_person_lookup).to respond_to(:get_status)
    expect(client.product_invoice_query).to respond_to(:retrieve, :download_pdf, :download_xml)
    expect(client.consumer_invoice_query).to respond_to(:retrieve, :download_xml)
    expect(client.tax_calculation).to respond_to(:calculate)
    expect(client.tax_codes).to respond_to(:list_operation_codes, :list_acquisition_purposes)
    expect(client.state_taxes).to respond_to(:list, :create, :retrieve, :update, :delete)
  end

  it "exposes the invoice resources as functional (non-stub) instances" do
    expect(client.service_invoices).to respond_to(:create, :list, :retrieve, :cancel)
    expect(client.product_invoices).to respond_to(:create, :create_with_state_tax, :list)
  end

  it "exposes the entity resources as functional (non-stub) instances" do
    expect(client.companies).to respond_to(:create, :list, :retrieve, :remove)
    expect(client.legal_people).to respond_to(:create, :list, :find_by_tax_number)
    expect(client.natural_people).to respond_to(:create, :list, :find_by_tax_number)
    expect(client.webhooks).to respond_to(:create, :test, :get_available_events)
  end

  it "exposes the two RTC addon accessors routed to the classic hosts" do
    expect(client.service_invoices_rtc).to be_a(Nfe::Resources::ServiceInvoicesRtc)
    expect(client.product_invoices_rtc).to be_a(Nfe::Resources::ProductInvoicesRtc)
    rtc_main = client.service_invoices_rtc.send(:api_family)
    rtc_cte = client.product_invoices_rtc.send(:api_family)
    expect(client.configuration.base_url_for(rtc_main)).to eq("https://api.nfe.io")
    expect(client.configuration.base_url_for(rtc_cte)).to eq("https://api.nfse.io")
  end
end
