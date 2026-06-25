# frozen_string_literal: true

RSpec.describe Nfe::Resources::AbstractResource do
  # A minimal client double that records the request kwargs and returns a canned
  # response, so the AbstractResource helpers can be exercised without network.
  subject(:resource) { cte_resource_class.new(client) }

  let(:recorded) { [] }
  let(:canned_response) { Nfe::Http::Response.new(status: 200, body: "{}") }

  let(:client) do
    recorder = recorded
    response = canned_response
    Class.new do
      define_method(:request) do |method, **kwargs|
        recorder << kwargs.merge(method: method)
        response
      end
    end.new
  end

  # DTO test double exposing the generated +from_api+ factory contract.
  let(:dto_klass) do
    Class.new do
      attr_reader :payload

      def initialize(payload)
        @payload = payload
      end

      def self.from_api(payload)
        new(payload)
      end
    end
  end

  # Concrete subclass for the :cte family, version "v1".
  let(:cte_resource_class) do
    Class.new(described_class) do
      def api_family = :cte
      public :get, :post, :put, :delete, :full_path, :download,
             :hydrate, :hydrate_list, :handle_async_response
    end
  end

  # Concrete subclass for the addresses family, empty version.
  let(:versionless_resource_class) do
    Class.new(described_class) do
      def api_family = :addresses
      def api_version = ""
      public :full_path
    end
  end

  describe "#full_path" do
    it "prefixes the api_version" do
      expect(resource.full_path("/companies/x")).to eq("/v1/companies/x")
    end

    it "returns the path unchanged when the version is empty" do
      versionless = versionless_resource_class.new(client)
      expect(versionless.full_path("/addresses/01310100")).to eq("/addresses/01310100")
    end
  end

  describe "HTTP verb helpers" do
    it "routes #get through the client for the resource family" do
      resource.get("/x", query: { a: 1 })
      expect(recorded.last).to include(method: :get, family: :cte,
                                       path: "/v1/x", query: { a: 1 })
    end

    it "routes #post with a body and idempotency key" do
      resource.post("/x", body: "payload", idempotency_key: "k-1")
      expect(recorded.last).to include(method: :post, family: :cte,
                                       path: "/v1/x", body: "payload",
                                       idempotency_key: "k-1")
    end

    it "routes #put and #delete" do
      resource.put("/x", body: "b")
      resource.delete("/x")
      expect(recorded.map { |r| r[:method] }).to include(:put, :delete)
    end

    it "threads request_options through to the client" do
      options = Nfe::RequestOptions.new(api_key: "tenant")
      resource.get("/x", request_options: options)
      expect(recorded.last[:request_options]).to be(options)
    end
  end

  describe "#hydrate" do
    it "delegates to the DTO factory and returns an instance" do
      result = resource.hydrate(dto_klass, { "id" => 1 })
      expect(result).to be_a(dto_klass)
      expect(result.payload).to eq({ "id" => 1 })
    end
  end

  describe "#download" do
    let(:canned_response) do
      Nfe::Http::Response.new(status: 200, body: "%PDF-1.4 binary".dup)
    end

    it "returns the body as binary-safe ASCII-8BIT bytes" do
      bytes = resource.download("/x/pdf")
      expect(bytes.encoding).to eq(Encoding::ASCII_8BIT)
      expect(bytes[0, 4]).to eq("%PDF")
    end
  end

  describe "#hydrate_list" do
    it "builds a page-style ListResponse" do
      payload = { "data" => [{ "id" => 1 }, { "id" => 2 }],
                  "pageIndex" => 1, "pageCount" => 5, "totalResults" => 42 }
      result = resource.hydrate_list(dto_klass, payload, wrapper_key: "data")

      expect(result).to be_a(Nfe::ListResponse)
      expect(result.data.map(&:payload)).to eq([{ "id" => 1 }, { "id" => 2 }])
      expect(result.page.page_index).to eq(1)
      expect(result.page.page_count).to eq(5)
      expect(result.page.total).to eq(42)
      expect(result.page.starting_after).to be_nil
    end

    it "builds a cursor-style ListResponse" do
      payload = { "data" => [{ "id" => 1 }],
                  "startingAfter" => "cur-a", "endingBefore" => "cur-b" }
      result = resource.hydrate_list(dto_klass, payload, wrapper_key: "data")

      expect(result.page.starting_after).to eq("cur-a")
      expect(result.page.ending_before).to eq("cur-b")
      expect(result.page.page_index).to be_nil
    end
  end

  describe "#handle_async_response" do
    it "returns Pending for a 202 with a Location header" do
      response = Nfe::Http::Response.new(
        status: 202,
        headers: { "location" => "/v1/companies/x/serviceinvoices/abc-123" }
      )
      result = resource.handle_async_response(response, issued_klass: dto_klass)

      expect(result).to be_a(Nfe::Pending)
      expect(result.invoice_id).to eq("abc-123")
      expect(result.location).to eq("/v1/companies/x/serviceinvoices/abc-123")
    end

    it "raises InvoiceProcessingError for a 202 without a Location" do
      response = Nfe::Http::Response.new(status: 202)
      expect { resource.handle_async_response(response, issued_klass: dto_klass) }
        .to raise_error(Nfe::InvoiceProcessingError, /Location/)
    end

    it "returns Issued with a hydrated DTO for a 201" do
      response = Nfe::Http::Response.new(status: 201, body: '{"id":"x"}')
      result = resource.handle_async_response(response, issued_klass: dto_klass)

      expect(result).to be_a(Nfe::Issued)
      expect(result.resource).to be_a(dto_klass)
      expect(result.resource.payload).to eq({ "id" => "x" })
    end
  end
end
