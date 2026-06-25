# frozen_string_literal: true

require "json"

RSpec.describe Nfe::Resources::LegalPeople do
  subject(:legal_people) { client.legal_people }

  let(:client) { Nfe::Client.new(api_key: "key") }
  let(:transport) { FakeTransport.new }

  before { allow(client).to receive(:build_transport).and_return(transport) }

  def json(status: 200, body: "{}")
    Nfe::Http::Response.new(status: status, body: body)
  end

  def last_request
    transport.requests.last
  end

  describe "#list" do
    it "unwraps the legalPeople envelope" do
      transport.enqueue(json(body: { "legalPeople" => [{ "id" => "lp1" }, { "id" => "lp2" }] }.to_json))

      result = legal_people.list("co-1")

      expect(result).to be_a(Nfe::ListResponse)
      expect(result.data.map(&:id)).to eq(%w[lp1 lp2])
      expect(last_request.url).to eq("https://api.nfe.io/v1/companies/co-1/legalpeople")
    end

    it "rejects an empty company_id without HTTP" do
      expect { legal_people.list("") }.to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#create" do
    it "POSTs and unwraps a single legal person" do
      transport.enqueue(json(body: { "legalPeople" => { "id" => "lp1", "name" => "Empresa" } }.to_json))

      person = legal_people.create("co-1", name: "Empresa", federalTaxNumber: "12345678000199")

      expect(person).to be_a(Nfe::LegalPerson)
      expect(person.id).to eq("lp1")
      expect(last_request.method).to eq("POST")
    end
  end

  describe "#retrieve / #update / #delete" do
    it "retrieves by id" do
      transport.enqueue(json(body: { "legalPeople" => { "id" => "lp1" } }.to_json))
      expect(legal_people.retrieve("co-1", "lp1").id).to eq("lp1")
      expect(last_request.url).to eq("https://api.nfe.io/v1/companies/co-1/legalpeople/lp1")
    end

    it "updates by id" do
      transport.enqueue(json(body: { "legalPeople" => { "id" => "lp1", "name" => "X" } }.to_json))
      expect(legal_people.update("co-1", "lp1", name: "X").name).to eq("X")
      expect(last_request.method).to eq("PUT")
    end

    it "deletes and returns nil" do
      transport.enqueue(json(status: 200, body: ""))
      expect(legal_people.delete("co-1", "lp1")).to be_nil
      expect(last_request.method).to eq("DELETE")
    end

    it "rejects an empty legal_person_id without HTTP" do
      expect { legal_people.retrieve("co-1", "") }.to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#create_batch" do
    it "creates sequentially in order" do
      transport.enqueue(json(body: { "legalPeople" => { "id" => "lp1" } }.to_json))
      transport.enqueue(json(body: { "legalPeople" => { "id" => "lp2" } }.to_json))

      created = legal_people.create_batch("co-1", [{ name: "A" }, { name: "B" }])

      expect(created.map(&:id)).to eq(%w[lp1 lp2])
      expect(transport.requests.length).to eq(2)
    end
  end

  describe "#find_by_tax_number" do
    it "matches by normalised CNPJ" do
      transport.enqueue(json(body: {
        "legalPeople" => [{ "id" => "lp1", "federalTaxNumber" => "12345678000199" }]
      }.to_json))

      found = legal_people.find_by_tax_number("co-1", "12.345.678/0001-99")
      expect(found.id).to eq("lp1")
    end
  end
end
