# frozen_string_literal: true

RSpec.describe Nfe::Http::Request do
  def build(**overrides)
    described_class.new(
      method: "GET",
      base_url: "https://api.nfse.io",
      path: "/v2/companies/abc/productinvoices",
      **overrides
    )
  end

  describe "defaults" do
    it "defaults the optional members" do
      request = build

      expect(request.headers).to eq({})
      expect(request.query).to eq({})
      expect(request.body).to be_nil
      expect(request.open_timeout).to be_nil
      expect(request.read_timeout).to be_nil
      expect(request.idempotency_key).to be_nil
    end
  end

  describe "#url" do
    it "composes base_url + path with no query" do
      expect(build.url).to eq("https://api.nfse.io/v2/companies/abc/productinvoices")
    end

    it "strips a trailing slash from base_url" do
      request = build(base_url: "https://api.nfse.io/")

      expect(request.url).to eq("https://api.nfse.io/v2/companies/abc/productinvoices")
    end

    it "appends the URL-encoded query with a leading ?" do
      request = build(query: { environment: "Production", limit: 50 })

      expect(request.url).to eq(
        "https://api.nfse.io/v2/companies/abc/productinvoices?environment=Production&limit=50"
      )
    end

    it "emits array query values as repeated keys" do
      request = build(query: { status: %w[Issued Cancelled] })

      expect(request.url).to eq(
        "https://api.nfse.io/v2/companies/abc/productinvoices?status=Issued&status=Cancelled"
      )
    end

    it "uses & when the path already contains a ?" do
      request = build(path: "/v2/companies?expand=tax", query: { limit: 10 })

      expect(request.url).to eq("https://api.nfse.io/v2/companies?expand=tax&limit=10")
    end

    it "omits the query string when query is empty" do
      expect(build(query: {}).url).not_to include("?")
    end
  end

  describe "#idempotent?" do
    %w[GET HEAD PUT DELETE get head put delete].each do |verb|
      it "is true for #{verb}" do
        expect(build(method: verb).idempotent?).to be(true)
      end
    end

    it "is false for POST without an idempotency_key" do
      expect(build(method: "POST").idempotent?).to be(false)
    end

    it "is true for POST carrying an idempotency_key" do
      expect(build(method: "POST", idempotency_key: "9f1c").idempotent?).to be(true)
    end
  end
end
