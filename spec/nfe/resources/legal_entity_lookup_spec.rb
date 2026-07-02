# frozen_string_literal: true

require "json"

RSpec.describe Nfe::Resources::LegalEntityLookup do
  subject(:lookup) { client.legal_entity_lookup }

  let(:client) { Nfe::Client.new(api_key: "key", data_api_key: "datakey") }
  let(:transport) { FakeTransport.new }

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def response(status: 200, body: "{}", headers: {})
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def last_request = transport.requests.last

  describe "#get_basic_info" do
    let(:payload) do
      { "legalEntity" => { "federalTaxNumber" => "12345678000190", "name" => "Acme S/A",
                           "tradeName" => "Acme", "status" => "Active", "statusOn" => "2020-01-15T00:00:00Z",
                           "size" => "EPP", "openedOn" => "2001-06-30T00:00:00Z", "email" => "fiscal@acme.com" } }
    end

    before { transport.enqueue(response(body: payload.to_json)) }

    it "routes to the legal-entity host and normalizes the CNPJ into the path" do
      lookup.get_basic_info("12.345.678/0001-90")

      expect(last_request.url).to start_with("https://legalentity.api.nfe.io")
      expect(last_request.url).to include("/v2/legalentities/basicInfo/12345678000190")
    end

    it "hydrates a LegalEntityBasicInfoResponse with a nested LegalEntity" do
      result = lookup.get_basic_info("12.345.678/0001-90")

      expect(result).to be_a(Nfe::LegalEntityBasicInfoResponse)
      expect(result.legal_entity).to be_a(Nfe::LegalEntity)
      expect(result.legal_entity.federal_tax_number).to eq("12345678000190")
      expect(result.legal_entity.name).to eq("Acme S/A")
    end

    it "maps statusOn/size/openedOn/email onto the real snake_case members" do
      legal_entity = lookup.get_basic_info("12.345.678/0001-90").legal_entity

      expect(legal_entity.status_on).to eq("2020-01-15T00:00:00Z")
      expect(legal_entity.size).to eq("EPP")
      expect(legal_entity.opened_on).to eq("2001-06-30T00:00:00Z")
      expect(legal_entity.email).to eq("fiscal@acme.com")
    end

    it "forwards update_address and update_city_code as query params" do
      lookup.get_basic_info("12.345.678/0001-90", update_address: true, update_city_code: false)

      expect(last_request.url).to include("updateAddress=true")
      expect(last_request.url).to include("updateCityCode=false")
    end

    it "omits opts that are nil" do
      lookup.get_basic_info("12.345.678/0001-90")

      expect(last_request.url).not_to include("updateAddress")
      expect(last_request.url).not_to include("updateCityCode")
    end

    it "rejects a wrong-length CNPJ before issuing any HTTP request" do
      expect { lookup.get_basic_info("123") }.to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#get_state_tax_info" do
    let(:payload) do
      { "legalEntity" => { "federalTaxNumber" => "12345678000190", "taxRegime" => "Normal",
                           "fiscalUnit" => "SP", "createdOn" => "2023-03-01T00:00:00Z", "checkCode" => "AB12",
                           "stateTaxes" => [{ "status" => "Abled", "taxNumber" => "111222333444",
                                              "statusOn" => "2010-05-01T00:00:00Z",
                                              "openedOn" => "2001-06-30T00:00:00Z",
                                              "code" => "SP", "address" => { "district" => "Centro", "state" => "SP" },
                                              "nfe" => { "status" => "Abled" } }] } }
    end

    before { transport.enqueue(response(body: payload.to_json)) }

    it "upcases the UF and normalizes the CNPJ into the path" do
      lookup.get_state_tax_info("sp", "12.345.678/0001-90")

      expect(last_request.url)
        .to include("/v2/legalentities/stateTaxInfo/SP/12345678000190")
    end

    it "hydrates a LegalEntityStateTaxResponse with the state-tax legalEntity" do
      result = lookup.get_state_tax_info("sp", "12.345.678/0001-90")

      expect(result).to be_a(Nfe::LegalEntityStateTaxResponse)
      expect(result.legal_entity).to be_a(Nfe::StateTaxLegalEntity)
      expect(result.legal_entity.tax_regime).to eq("Normal")
      expect(result.legal_entity.fiscal_unit).to eq("SP")
      expect(result.legal_entity.check_code).to eq("AB12")
    end

    it "hydrates the nested stateTaxes registrations" do
      state_taxes = lookup.get_state_tax_info("sp", "12.345.678/0001-90").legal_entity.state_taxes

      expect(state_taxes.first).to be_a(Nfe::StateTaxLegalEntity::StateTax)
      expect(state_taxes.first.tax_number).to eq("111222333444")
      expect(state_taxes.first.status_on).to eq("2010-05-01T00:00:00Z")
      expect(state_taxes.first.code).to eq("SP")
      expect(state_taxes.first.address.district).to eq("Centro")
      expect(state_taxes.first.nfe.status).to eq("Abled")
    end

    it "rejects an invalid UF before issuing any HTTP request" do
      expect { lookup.get_state_tax_info("XX", "12.345.678/0001-90") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#get_state_tax_for_invoice" do
    before { transport.enqueue(response(body: { "legalEntity" => { "taxRegime" => "Normal" } }.to_json)) }

    it "routes to the stateTaxForInvoice path and hydrates the for-invoice response" do
      result = lookup.get_state_tax_for_invoice("sp", "12.345.678/0001-90")

      expect(last_request.url)
        .to include("/v2/legalentities/stateTaxForInvoice/SP/12345678000190")
      expect(result).to be_a(Nfe::LegalEntityStateTaxForInvoiceResponse)
      expect(result.legal_entity).to be_a(Nfe::StateTaxLegalEntity)
    end
  end

  describe "#get_suggested_state_tax_for_invoice" do
    before { transport.enqueue(response(body: { "legalEntity" => { "taxRegime" => "Normal" } }.to_json)) }

    it "routes to the stateTaxSuggestedForInvoice path and hydrates the for-invoice response" do
      result = lookup.get_suggested_state_tax_for_invoice("sp", "12.345.678/0001-90")

      expect(last_request.url)
        .to include("/v2/legalentities/stateTaxSuggestedForInvoice/SP/12345678000190")
      expect(result).to be_a(Nfe::LegalEntityStateTaxForInvoiceResponse)
      expect(result.legal_entity).to be_a(Nfe::StateTaxLegalEntity)
    end
  end
end
