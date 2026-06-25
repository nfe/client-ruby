# frozen_string_literal: true

require "json"

RSpec.describe Nfe::Resources::Addresses do
  subject(:addresses) { client.addresses }

  let(:client) { Nfe::Client.new(api_key: "key", data_api_key: "datakey") }
  let(:transport) { FakeTransport.new }

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def response(status: 200, body: "{}", headers: {})
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def last_request = transport.requests.last

  describe "#lookup_by_postal_code" do
    # Real API shape (openapi/consulta-endereco.yaml): district, the nested
    # city {code, name} object, numberMin/numberMax and postalCode are the
    # exact camelCase keys returned by address.api.nfe.io/v2.
    let(:address_item) do
      { "street" => "Paulista", "streetSuffix" => "Avenida", "number" => "1000",
        "numberMin" => "0001", "numberMax" => "1999", "district" => "Bela Vista",
        "additionalInformation" => "lado par", "postalCode" => "01310100",
        "city" => { "code" => "3550308", "name" => "São Paulo" },
        "state" => "SP", "country" => "BR" }
    end
    let(:payload) { { "addresses" => [address_item] } }

    before { transport.enqueue(response(body: payload.to_json)) }

    it "routes to the address data host with the /v2 prefix already embedded" do
      addresses.lookup_by_postal_code("01310-100")

      expect(last_request.url).to start_with("https://address.api.nfe.io/v2")
      expect(last_request.method).to eq("GET")
    end

    it "normalizes the CEP into the request path" do
      addresses.lookup_by_postal_code("01310-100")

      expect(last_request.url).to include("/addresses/01310100")
    end

    it "hydrates the addresses array into an AddressLookupResponse" do
      result = addresses.lookup_by_postal_code("01310-100")

      expect(result).to be_a(Nfe::AddressLookupResponse)
      expect(result.addresses.first).to be_a(Nfe::Address)
      expect(result.addresses.first.street).to eq("Paulista")
      expect(result.addresses.first.postal_code).to eq("01310100")
    end

    it "maps the real district/numberMin/numberMax keys onto their members" do
      address = addresses.lookup_by_postal_code("01310-100").addresses.first

      expect(address.district).to eq("Bela Vista")
      expect(address.number_min).to eq("0001")
      expect(address.number_max).to eq("1999")
      expect(address.street_suffix).to eq("Avenida")
    end

    it "hydrates the nested city object into Address::City with code and name" do
      city = addresses.lookup_by_postal_code("01310-100").addresses.first.city

      expect(city).to be_a(Nfe::Address::City)
      expect(city.code).to eq("3550308")
      expect(city.name).to eq("São Paulo")
    end

    it "rejects a wrong-length CEP before issuing any HTTP request" do
      expect { addresses.lookup_by_postal_code("123") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#search" do
    before { transport.enqueue(response(body: { "addresses" => [] }.to_json)) }

    it "forwards a present filter as $filter" do
      addresses.search(filter: "city eq 'SP'")

      expect(last_request.url).to include("%24filter=").or include("$filter=")
      expect(last_request.url).to start_with("https://address.api.nfe.io/v2/addresses")
    end

    it "omits the query entirely when no filter is given" do
      addresses.search

      expect(last_request.url).not_to include("filter")
    end
  end

  describe "#lookup_by_term" do
    before { transport.enqueue(response(body: { "addresses" => [] }.to_json)) }

    it "URL-encodes the term into the path" do
      addresses.lookup_by_term("Avenida Paulista")

      expect(last_request.url).to include("/addresses/Avenida")
      expect(last_request.url).to include("+").or include("%20")
    end

    it "rejects an empty/whitespace term before issuing any HTTP request" do
      expect { addresses.lookup_by_term("   ") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end
end
