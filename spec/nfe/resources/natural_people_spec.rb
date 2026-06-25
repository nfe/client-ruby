# frozen_string_literal: true

require "json"

RSpec.describe Nfe::Resources::NaturalPeople do
  subject(:natural_people) { client.natural_people }

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
    it "unwraps the naturalPeople envelope and routes to naturalpeople" do
      transport.enqueue(json(body: { "naturalPeople" => [{ "id" => "np1" }] }.to_json))

      result = natural_people.list("co-1")

      expect(result.data.map(&:id)).to eq(%w[np1])
      expect(last_request.url).to eq("https://api.nfe.io/v1/companies/co-1/naturalpeople")
    end

    it "rejects an empty company_id without HTTP" do
      expect { natural_people.list("") }.to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#create" do
    it "POSTs and unwraps a single natural person" do
      transport.enqueue(json(body: { "naturalPeople" => { "id" => "np1", "name" => "João" } }.to_json))

      person = natural_people.create("co-1", name: "João", federalTaxNumber: "12345678901")

      expect(person).to be_a(Nfe::NaturalPerson)
      expect(person.id).to eq("np1")
    end
  end

  describe "#delete" do
    it "deletes and returns nil" do
      transport.enqueue(json(status: 200, body: ""))
      expect(natural_people.delete("co-1", "np1")).to be_nil
      expect(last_request.method).to eq("DELETE")
    end
  end

  describe "#create_batch" do
    it "creates sequentially in order" do
      transport.enqueue(json(body: { "naturalPeople" => { "id" => "np1" } }.to_json))
      transport.enqueue(json(body: { "naturalPeople" => { "id" => "np2" } }.to_json))

      created = natural_people.create_batch("co-1", [{ name: "A" }, { name: "B" }])

      expect(created.map(&:id)).to eq(%w[np1 np2])
      expect(transport.requests.length).to eq(2)
    end
  end

  describe "#find_by_tax_number" do
    it "normalises a formatted CPF to 11 digits before matching" do
      transport.enqueue(json(body: {
        "naturalPeople" => [{ "id" => "np1", "federalTaxNumber" => "12345678901" }]
      }.to_json))

      found = natural_people.find_by_tax_number("co-1", "123.456.789-01")
      expect(found.id).to eq("np1")
    end
  end
end
