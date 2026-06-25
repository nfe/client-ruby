# frozen_string_literal: true

require "openssl"
require "json"
require "securerandom"

RSpec.describe Nfe::Webhook do
  let(:secret) { "super-secret-key" }
  let(:body) { %({"action":"invoice.issued","payload":{"id":"abc","status":"Issued"}}) }

  def sign(payload, key)
    "sha1=#{OpenSSL::HMAC.hexdigest('SHA1', key, payload)}"
  end

  describe ".verify_signature" do
    it "accepts a valid lowercase-hex signature" do
      sig = sign(body, secret)
      expect(described_class.verify_signature(payload: body, signature: sig, secret: secret)).to be(true)
    end

    it "accepts an uppercase-hex digest as NFE.io sends it" do
      digest = OpenSSL::HMAC.hexdigest("SHA1", secret, body).upcase
      sig = "sha1=#{digest}"
      expect(described_class.verify_signature(payload: body, signature: sig, secret: secret)).to be(true)
    end

    it "accepts an uppercase prefix (case-insensitive prefix)" do
      digest = OpenSSL::HMAC.hexdigest("SHA1", secret, body)
      sig = "SHA1=#{digest}"
      expect(described_class.verify_signature(payload: body, signature: sig, secret: secret)).to be(true)
    end

    it "round-trips a self-computed signature for a random body and secret" do
      random_body = SecureRandom.hex(64)
      random_secret = SecureRandom.hex(16)
      sig = sign(random_body, random_secret)
      expect(
        described_class.verify_signature(payload: random_body, signature: sig, secret: random_secret)
      ).to be(true)
    end

    it "uses the first element when the signature is a single-element array" do
      sig = sign(body, secret)
      expect(described_class.verify_signature(payload: body, signature: [sig], secret: secret)).to be(true)
    end

    context "with negative inputs (must return false and never raise)" do
      it "rejects a tampered body" do
        sig = sign(body, secret)
        tampered = body.sub("abc", "abd")
        result = nil
        expect { result = described_class.verify_signature(payload: tampered, signature: sig, secret: secret) }
          .not_to raise_error
        expect(result).to be(false)
      end

      it "rejects a valid signature checked against the wrong secret" do
        sig = sign(body, secret)
        expect(described_class.verify_signature(payload: body, signature: sig, secret: "other-secret")).to be(false)
      end

      it "rejects a sha256= downgrade attempt without raising" do
        digest = "a" * 64
        sig = "sha256=#{digest}"
        result = nil
        expect { result = described_class.verify_signature(payload: body, signature: sig, secret: secret) }
          .not_to raise_error
        expect(result).to be(false)
      end

      it "rejects a bare 40-char hex with no prefix" do
        bare = OpenSSL::HMAC.hexdigest("SHA1", secret, body)
        expect(described_class.verify_signature(payload: body, signature: bare, secret: secret)).to be(false)
      end

      it "rejects a wrong-length signature (sha1=abc)" do
        result = nil
        expect { result = described_class.verify_signature(payload: body, signature: "sha1=abc", secret: secret) }
          .not_to raise_error
        expect(result).to be(false)
      end

      it "rejects non-hex content of the right length" do
        sig = "sha1=#{'z' * 40}"
        expect(described_class.verify_signature(payload: body, signature: sig, secret: secret)).to be(false)
      end

      it "rejects a nil secret" do
        sig = sign(body, secret)
        expect(described_class.verify_signature(payload: body, signature: sig, secret: nil)).to be(false)
      end

      it "rejects an empty secret" do
        sig = sign(body, secret)
        expect(described_class.verify_signature(payload: body, signature: sig, secret: "")).to be(false)
      end

      it "rejects a nil signature" do
        expect(described_class.verify_signature(payload: body, signature: nil, secret: secret)).to be(false)
      end

      it "rejects an empty-string signature" do
        expect(described_class.verify_signature(payload: body, signature: "", secret: secret)).to be(false)
      end

      it "rejects an empty array signature" do
        expect(described_class.verify_signature(payload: body, signature: [], secret: secret)).to be(false)
      end

      it "never raises across the whole negative matrix" do
        cases = [nil, "", [], "sha1=abc", "sha256=#{'a' * 64}", "no-prefix",
                 "sha1=#{'z' * 40}", ["sha1=#{'a' * 40}"]]
        cases.each do |candidate|
          expect { described_class.verify_signature(payload: body, signature: candidate, secret: secret) }
            .not_to raise_error
        end
      end
    end
  end

  describe ".construct_event" do
    it "returns a WebhookEvent for a valid action/payload envelope" do
      sig = sign(body, secret)
      event = described_class.construct_event(payload: body, signature: sig, secret: secret)
      expect(event).to be_a(Nfe::WebhookEvent)
      expect(event.type).to eq("invoice.issued")
      expect(event.data).to eq("id" => "abc", "status" => "Issued")
      expect(event.id).to eq("abc")
    end

    it "unwraps the event/data envelope shape" do
      payload = %({"event":"company.updated","data":{"id":"co_1"}})
      sig = sign(payload, secret)
      event = described_class.construct_event(payload: payload, signature: sig, secret: secret)
      expect(event.type).to eq("company.updated")
      expect(event.data).to eq("id" => "co_1")
      expect(event.id).to eq("co_1")
    end

    it "surfaces nil id when the envelope carries none" do
      payload = %({"action":"invoice.failed","payload":{"status":"Failed"}})
      sig = sign(payload, secret)
      event = described_class.construct_event(payload: payload, signature: sig, secret: secret)
      expect(event.id).to be_nil
    end

    it "raises SignatureVerificationError on a bad signature" do
      expect do
        described_class.construct_event(payload: body, signature: "sha1=#{'a' * 40}", secret: secret)
      end.to raise_error(Nfe::SignatureVerificationError)
    end

    it "raises SignatureVerificationError on malformed JSON with a valid signature" do
      malformed = "{not json"
      sig = sign(malformed, secret)
      expect do
        described_class.construct_event(payload: malformed, signature: sig, secret: secret)
      end.to raise_error(Nfe::SignatureVerificationError)
    end

    it "raises SignatureVerificationError when the JSON is not an object" do
      payload = "[1,2,3]"
      sig = sign(payload, secret)
      expect do
        described_class.construct_event(payload: payload, signature: sig, secret: secret)
      end.to raise_error(Nfe::SignatureVerificationError)
    end
  end
end
