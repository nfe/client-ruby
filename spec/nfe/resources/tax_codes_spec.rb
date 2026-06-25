# frozen_string_literal: true

RSpec.describe Nfe::Resources::TaxCodes do
  subject(:tax_codes) { client.tax_codes }

  let(:client) { Nfe::Client.new(api_key: "key", data_api_key: "datakey") }
  let(:transport) { FakeTransport.new }
  let(:payload) do
    {
      "currentPage" => 1,
      "totalPages" => 3,
      "totalCount" => 42,
      "items" => [
        { "code" => "1", "description" => "Venda" },
        { "code" => "2", "description" => "Compra" }
      ]
    }
  end

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def response(status: 200, body: "{}", headers: {})
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def last_request = transport.requests.last

  describe "#list_operation_codes" do
    before { transport.enqueue(response(body: payload.to_json)) }

    it "GETs the operation-code path on the api.nfse.io host" do
      tax_codes.list_operation_codes

      expect(last_request.method).to eq("GET")
      expect(last_request.url).to start_with("https://api.nfse.io")
      expect(last_request.url).to include("/tax-codes/operation-code")
    end

    it "returns a hydrated TaxCodePaginatedResponse (page-style, not ListResponse)" do
      result = tax_codes.list_operation_codes

      expect(result).to be_a(Nfe::TaxCodePaginatedResponse)
      expect(result).not_to be_a(Nfe::ListResponse)
      expect(result.current_page).to eq(1)
      expect(result.total_pages).to eq(3)
      expect(result.total_count).to eq(42)
      expect(result.items.map(&:code)).to eq(%w[1 2])
      expect(result.items.first).to be_a(Nfe::TaxCode)
    end

    it "omits pageIndex/pageCount from the URL by default" do
      tax_codes.list_operation_codes

      expect(last_request.url).not_to include("pageIndex")
      expect(last_request.url).not_to include("pageCount")
    end

    it "sends explicit 1-based pageIndex/pageCount preserved as given" do
      tax_codes.list_operation_codes(page_index: 2, page_count: 20)

      expect(last_request.url).to include("pageIndex=2").and include("pageCount=20")
    end
  end

  describe "the four endpoint paths" do
    before { transport.enqueue(response(body: payload.to_json)) }

    it "targets /tax-codes/acquisition-purpose" do
      tax_codes.list_acquisition_purposes
      expect(last_request.url).to include("/tax-codes/acquisition-purpose")
    end

    it "targets /tax-codes/issuer-tax-profile" do
      tax_codes.list_issuer_tax_profiles
      expect(last_request.url).to include("/tax-codes/issuer-tax-profile")
    end

    it "targets /tax-codes/recipient-tax-profile" do
      tax_codes.list_recipient_tax_profiles
      expect(last_request.url).to include("/tax-codes/recipient-tax-profile")
    end
  end
end
