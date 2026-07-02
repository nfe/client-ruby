# frozen_string_literal: true

require "openssl"
require "time"

RSpec.describe Nfe::CertificateValidator do
  # Build a self-signed cert + PKCS#12 in-memory so the spec needs no fixture
  # file on disk.
  def build_pfx(password:, not_after: Time.now + (365 * 24 * 60 * 60))
    key = OpenSSL::PKey::RSA.new(2048)
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = 4242
    name = OpenSSL::X509::Name.parse("/CN=Acme Test/O=NFE.io Spec")
    cert.subject = name
    cert.issuer = name
    cert.public_key = key.public_key
    cert.not_before = Time.now - 60
    cert.not_after = not_after
    cert.sign(key, OpenSSL::Digest.new("SHA256"))
    OpenSSL::PKCS12.create(password, "spec-cert", key, cert).to_der
  end

  describe ".supported_format?" do
    it "is true for .pfx, .p12 and uppercase variants" do
      %w[cert.pfx cert.p12 CERT.PFX a.b.P12].each do |name|
        expect(described_class.supported_format?(name)).to be(true)
      end
    end

    it "is false for unsupported extensions and nil" do
      ["cert.pem", "cert.txt", "noext", "", nil].each do |name|
        expect(described_class.supported_format?(name)).to be(false)
      end
    end
  end

  describe ".validate" do
    let(:password) { "pfx-pass-123" }
    let(:expiry) { Time.now + (200 * 24 * 60 * 60) }
    let(:der) { build_pfx(password: password, not_after: expiry) }

    it "extracts real metadata with the correct password" do
      info = described_class.validate(der, password)
      expect(info).to be_a(Nfe::CertificateInfo)
      expect(info.subject).to include("Acme Test")
      expect(info.issuer).to include("Acme Test")
      expect(info.serial_number).to eq("4242")
      expect(info.not_after).to be_within(60).of(expiry)
      expect(info.not_before).to be_a(Time)
    end

    it "raises InvalidRequestError on a wrong password" do
      expect { described_class.validate(der, "wrong-password") }
        .to raise_error(Nfe::InvalidRequestError, /Certificado ou senha inválidos/)
    end

    it "raises InvalidRequestError on non-DER bytes" do
      expect { described_class.validate("not a certificate at all", password) }
        .to raise_error(Nfe::InvalidRequestError, /Certificado ou senha inválidos/)
    end

    it "never leaks the password into the raised error" do
      described_class.validate(der, "leak-check-secret")
    rescue Nfe::InvalidRequestError => e
      expect(e.message).not_to include("leak-check-secret")
    end
  end

  describe ".days_until_expiration" do
    it "counts whole days for a future expiry" do
      future = Time.now + (10 * 24 * 60 * 60) + 3600
      expect(described_class.days_until_expiration(future)).to eq(10)
    end

    it "is negative once expired" do
      past = Time.now - (5 * 24 * 60 * 60)
      expect(described_class.days_until_expiration(past)).to be < 0
    end

    it "accepts an ISO-8601 string" do
      future = (Time.now + (3 * 24 * 60 * 60) + 7200).utc.iso8601
      expect(described_class.days_until_expiration(future)).to eq(3)
    end
  end

  describe ".expiring_soon?" do
    it "is true within the default 30-day threshold" do
      soon = Time.now + (10 * 24 * 60 * 60) + 3600
      expect(described_class.expiring_soon?(soon)).to be(true)
    end

    it "is false beyond the threshold" do
      later = Time.now + (200 * 24 * 60 * 60)
      expect(described_class.expiring_soon?(later)).to be(false)
    end

    it "is false once already expired (negative days)" do
      past = Time.now - (1 * 24 * 60 * 60)
      expect(described_class.expiring_soon?(past)).to be(false)
    end

    it "honours a custom threshold" do
      in_50_days = Time.now + (50 * 24 * 60 * 60) + 3600
      expect(described_class.expiring_soon?(in_50_days, 60)).to be(true)
      expect(described_class.expiring_soon?(in_50_days, 30)).to be(false)
    end
  end
end
