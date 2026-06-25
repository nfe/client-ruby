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

  it "raises NotImplementedError naming the filling change on a not-yet-filled resource" do
    # The :main entity resources (companies, legal_people, natural_people,
    # webhooks) are implemented by add-entity-resources; the remaining stubs
    # still raise NotImplementedError naming their filling change.
    expect { client.service_invoices.create }
      .to raise_error(NotImplementedError, /add-invoice-resources/)
    expect { client.addresses.retrieve }
      .to raise_error(NotImplementedError, /add-lookup-resources/)
  end

  it "exposes the entity resources as functional (non-stub) instances" do
    expect(client.companies).to respond_to(:create, :list, :retrieve, :remove)
    expect(client.legal_people).to respond_to(:create, :list, :find_by_tax_number)
    expect(client.natural_people).to respond_to(:create, :list, :find_by_tax_number)
    expect(client.webhooks).to respond_to(:create, :test, :get_available_events)
  end
end
