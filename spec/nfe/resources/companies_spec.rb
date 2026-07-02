# frozen_string_literal: true

require "openssl"
require "json"

RSpec.describe Nfe::Resources::Companies do
  subject(:companies) { client.companies }

  let(:client) { Nfe::Client.new(api_key: "key") }
  let(:transport) { FakeTransport.new }
  # A real self-signed PKCS#12, generated in-memory (no temp file on disk).
  let(:pfx) do
    key = OpenSSL::PKey::RSA.new(2048)
    name = OpenSSL::X509::Name.parse("/CN=Acme Test/O=NFE")
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 4242
    cert.subject = name
    cert.issuer = name
    cert.public_key = key.public_key
    cert.not_before = Time.now - 86_400
    cert.not_after = Time.now + (40 * 86_400)
    cert.sign(key, OpenSSL::Digest.new("SHA256"))
    OpenSSL::PKCS12.create("secret", "acme", key, cert).to_der
  end

  # Route every request through a request-capturing fake transport.
  before { allow(client).to receive(:build_transport).and_return(transport) }

  def json(status: 200, body: "{}", headers: {})
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def last_request
    transport.requests.last
  end

  describe "#create" do
    before { transport.enqueue(json(body: { "companies" => { "id" => "abc", "name" => "Acme" } }.to_json)) }

    it "POSTs to the main host and returns a hydrated Company" do
      company = companies.create(name: "Acme", federalTaxNumber: "12345678000199")

      expect(company).to be_a(Nfe::Company)
      expect(company.id).to eq("abc")
      expect(last_request.method).to eq("POST")
      expect(last_request.url).to start_with("https://api.nfe.io/v1/companies")
      expect(last_request.headers["Content-Type"]).to eq("application/json")
    end

    it "rejects a wrong-length tax number before issuing HTTP" do
      expect { companies.create(name: "X", federalTaxNumber: "123") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end

    it "accepts a 14-char alphanumeric CNPJ without numeric coercion" do
      companies.create(name: "X", federalTaxNumber: "12ABC678000199")
      sent = JSON.parse(last_request.body)
      expect(sent["federalTaxNumber"]).to eq("12ABC678000199")
    end

    it "rejects a malformed e-mail before HTTP" do
      expect { companies.create(name: "X", email: "not-an-email") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#list" do
    before do
      transport.enqueue(json(body: { "companies" => [{ "id" => "a" }, { "id" => "b" }], "page" => 1 }.to_json))
    end

    it "converts the API 1-based page to a 0-based page_index" do
      result = companies.list(page_index: 0, page_count: 20)

      expect(result).to be_a(Nfe::ListResponse)
      expect(result.data.map(&:id)).to eq(%w[a b])
      expect(result.page.page_index).to eq(0)
      expect(result.page.page_count).to eq(20)
      # page_index 0 (0-based) é enviado como pageIndex=1 (1-based, exigido pela API)
      expect(last_request.url).to include("pageIndex=1").and include("pageCount=20")
    end
  end

  describe "#list_all" do
    it "auto-paginates until a short page is returned" do
      full = (1..100).map { |i| { "id" => "c#{i}" } }
      transport.enqueue(json(body: { "companies" => full, "page" => 1 }.to_json))
      transport.enqueue(json(body: { "companies" => [{ "id" => "tail" }], "page" => 2 }.to_json))

      all = companies.list_all

      expect(all.length).to eq(101)
      expect(all.last.id).to eq("tail")
      expect(transport.requests.length).to eq(2)
    end
  end

  describe "#list_each" do
    it "returns an Enumerator yielding companies on demand" do
      transport.enqueue(json(body: { "companies" => [{ "id" => "a" }], "page" => 1 }.to_json))
      enum = companies.list_each

      expect(enum).to be_a(Enumerator)
      expect(enum.first.id).to eq("a")
    end
  end

  describe "#retrieve" do
    it "unwraps the companies envelope" do
      transport.enqueue(json(body: { "companies" => { "id" => "abc" } }.to_json))
      expect(companies.retrieve("abc").id).to eq("abc")
      expect(last_request.url).to eq("https://api.nfe.io/v1/companies/abc")
    end

    it "raises NotFoundError on 404" do
      transport.enqueue(json(status: 404, body: "{}"))
      expect { companies.retrieve("missing") }.to raise_error(Nfe::NotFoundError)
    end

    it "rejects an empty company_id without HTTP" do
      expect { companies.retrieve("  ") }.to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#update" do
    it "PUTs and unwraps" do
      transport.enqueue(json(body: { "companies" => { "id" => "abc", "name" => "New" } }.to_json))
      company = companies.update("abc", name: "New")
      expect(company.name).to eq("New")
      expect(last_request.method).to eq("PUT")
    end
  end

  describe "#remove" do
    it "returns a deletion confirmation" do
      transport.enqueue(json(status: 200, body: ""))
      expect(companies.remove("abc")).to eq({ deleted: true, id: "abc" })
      expect(last_request.method).to eq("DELETE")
    end
  end

  describe "#find_by_tax_number" do
    it "finds by normalised federal tax number" do
      transport.enqueue(json(body: {
        "companies" => [{ "id" => "a", "federalTaxNumber" => "12345678000199" }], "page" => 1
      }.to_json))
      found = companies.find_by_tax_number("12.345.678/0001-99")
      expect(found.id).to eq("a")
    end

    it "returns nil when not found" do
      transport.enqueue(json(body: { "companies" => [], "page" => 1 }.to_json))
      expect(companies.find_by_tax_number("12345678000199")).to be_nil
    end
  end

  describe "#find_by_name" do
    it "matches case-insensitively" do
      transport.enqueue(json(body: {
        "companies" => [{ "id" => "a", "name" => "Acme Corp" }, { "id" => "b", "name" => "Other" }],
        "page" => 1
      }.to_json))
      expect(companies.find_by_name("acme").map(&:id)).to eq(["a"])
    end

    it "raises on an empty name" do
      expect { companies.find_by_name("   ") }.to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#validate_certificate" do
    it "extracts real metadata with the correct password (no HTTP)" do
      info = companies.validate_certificate(file: pfx, password: "secret")
      expect(info).to be_a(Nfe::CertificateInfo)
      expect(info.subject).to include("Acme Test")
      expect(info.not_after).to be > Time.now
      expect(transport.requests).to be_empty
    end

    it "raises InvalidRequestError on a wrong password" do
      expect { companies.validate_certificate(file: pfx, password: "wrong") }
        .to raise_error(Nfe::InvalidRequestError)
    end
  end

  describe "#upload_certificate" do
    before { transport.enqueue(json(body: { "message" => "ok" }.to_json)) }

    it "POSTs a multipart body carrying file and password" do
      result = companies.upload_certificate("abc", file: pfx, password: "secret", filename: "cert.pfx")

      expect(result).to eq({ uploaded: true, message: "ok" })
      expect(last_request.url).to eq("https://api.nfe.io/v1/companies/abc/certificate")
      content_type = last_request.headers["Content-Type"]
      expect(content_type).to start_with("multipart/form-data; boundary=")
      body = last_request.body
      expect(body).to include('name="file"').and include('name="password"')
      expect(body).to include("secret")
    end

    it "rejects an unsupported extension before HTTP" do
      expect { companies.upload_certificate("abc", file: pfx, password: "secret", filename: "cert.pem") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end

    it "fails fast on a wrong password before HTTP" do
      expect { companies.upload_certificate("abc", file: pfx, password: "wrong", filename: "cert.pfx") }
        .to raise_error(Nfe::InvalidRequestError)
      expect(transport.requests).to be_empty
    end
  end

  describe "#replace_certificate" do
    it "behaves like upload_certificate" do
      transport.enqueue(json(body: "{}"))
      expect(companies.replace_certificate("abc", file: pfx,
                                                  password: "secret")).to eq({ uploaded: true, message: nil })
    end
  end

  describe "#get_certificate_status" do
    it "computes days_until_expiration and expiring_soon from expires_on" do
      expires = (Time.now + (10 * 86_400)).iso8601
      transport.enqueue(json(body: { "hasCertificate" => true, "expiresOn" => expires, "isValid" => true }.to_json))

      status = companies.get_certificate_status("abc")

      expect(status).to be_a(Nfe::CertificateStatus)
      expect(status.has_certificate).to be(true)
      expect(status.days_until_expiration).to be_between(8, 10)
      expect(status.expiring_soon).to be(true)
    end

    it "leaves computed fields nil when there is no certificate" do
      transport.enqueue(json(body: { "hasCertificate" => false }.to_json))
      status = companies.get_certificate_status("abc")
      expect(status.days_until_expiration).to be_nil
      expect(status.expiring_soon).to be_nil
    end
  end

  describe "#check_certificate_expiration" do
    it "returns a warning within the threshold" do
      expires = (Time.now + (10 * 86_400)).iso8601
      transport.enqueue(json(body: { "hasCertificate" => true, "expiresOn" => expires, "isValid" => true }.to_json))

      warning = companies.check_certificate_expiration("abc", threshold_days: 30)
      expect(warning[:expiring]).to be(true)
      expect(warning[:days_remaining]).to be_between(8, 10)
    end

    it "returns nil outside the threshold" do
      expires = (Time.now + (200 * 86_400)).iso8601
      transport.enqueue(json(body: { "hasCertificate" => true, "expiresOn" => expires }.to_json))
      expect(companies.check_certificate_expiration("abc", threshold_days: 30)).to be_nil
    end
  end

  describe "#get_companies_with_expiring_certificates" do
    it "lists companies, skips lookup failures, and keeps the expiring ones" do
      expires = (Time.now + (10 * 86_400)).iso8601
      transport.enqueue(json(body: {
        "companies" => [{ "id" => "ok" }, { "id" => "boom" }], "page" => 1
      }.to_json))
      transport.enqueue(json(body: { "hasCertificate" => true, "expiresOn" => expires }.to_json)) # status for "ok"
      transport.enqueue(json(status: 500, body: "{}")) # status for "boom" -> skipped

      result = companies.get_companies_with_expiring_certificates(threshold_days: 30)
      expect(result.map(&:id)).to eq(["ok"])
    end
  end

  describe "main-host routing" do
    it "targets https://api.nfe.io/v1 for every call" do
      transport.enqueue(json(body: { "companies" => [], "page" => 1 }.to_json))
      companies.list
      expect(last_request.url).to start_with("https://api.nfe.io/v1/companies")
    end
  end
end
