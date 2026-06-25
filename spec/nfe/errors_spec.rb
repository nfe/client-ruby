# frozen_string_literal: true

RSpec.describe Nfe::Error do
  describe "#initialize" do
    it "defaults all response context to nil/empty" do
      error = described_class.new("boom")

      expect(error.message).to eq("boom")
      expect(error.status_code).to be_nil
      expect(error.request_id).to be_nil
      expect(error.error_code).to be_nil
      expect(error.response_body).to be_nil
      expect(error.response_headers).to eq({})
    end

    it "carries the full response context" do
      error = described_class.new(
        "bad",
        status_code: 422,
        request_id: "req_1",
        error_code: "INVALID",
        response_body: '{"message":"bad"}',
        response_headers: { "x-nfe-apikey" => "secret" }
      )

      expect(error.status_code).to eq(422)
      expect(error.request_id).to eq("req_1")
      expect(error.error_code).to eq("INVALID")
      expect(error.response_body).to eq('{"message":"bad"}')
      expect(error.response_headers).to eq("x-nfe-apikey" => "secret")
    end

    it "tolerates a nil response_headers" do
      expect(described_class.new("x", response_headers: nil).response_headers).to eq({})
    end
  end

  describe "#to_h" do
    subject(:hash) do
      described_class.new(
        "CNPJ inválido",
        status_code: 422,
        request_id: "req_1",
        error_code: "INVALID_CNPJ",
        response_body: '{"apikey":"super-secret"}',
        response_headers: { "x-nfe-apikey" => "super-secret" }
      ).to_h
    end

    it "exposes the logging-safe fields" do
      expect(hash).to eq(
        type: "Nfe::Error",
        message: "CNPJ inválido",
        status_code: 422,
        request_id: "req_1",
        error_code: "INVALID_CNPJ"
      )
    end

    it "never includes raw headers or body that could carry secrets" do
      expect(hash).not_to have_key(:response_headers)
      expect(hash).not_to have_key(:response_body)
      expect(hash.values.join(" ")).not_to include("super-secret")
    end
  end

  describe "the error hierarchy" do
    it "roots every concrete error at Nfe::Error" do
      [
        Nfe::AuthenticationError, Nfe::AuthorizationError, Nfe::InvalidRequestError,
        Nfe::NotFoundError, Nfe::ConflictError, Nfe::RateLimitError,
        Nfe::ServerError, Nfe::ApiConnectionError, Nfe::TimeoutError,
        Nfe::SignatureVerificationError, Nfe::ConfigurationError,
        Nfe::InvoiceProcessingError
      ].each do |klass|
        expect(klass.ancestors).to include(described_class)
      end
    end

    it "makes TimeoutError a kind of ApiConnectionError" do
      expect(Nfe::TimeoutError.new).to be_a(Nfe::ApiConnectionError)
      expect(Nfe::TimeoutError.ancestors).to include(Nfe::ApiConnectionError)
    end
  end

  describe Nfe::RateLimitError do
    it "exposes retry_after alongside the base attributes" do
      error = described_class.new("slow down", retry_after: 30, status_code: 429, request_id: "req_9")

      expect(error.retry_after).to eq(30)
      expect(error.status_code).to eq(429)
      expect(error.request_id).to eq("req_9")
    end

    it "defaults retry_after to nil" do
      expect(described_class.new("slow down").retry_after).to be_nil
    end
  end

  describe Nfe::ConfigurationError do
    it "is a kind of Nfe::Error" do
      expect(described_class.new("api_key ausente")).to be_a(Nfe::Error)
    end

    it "carries the base response context like any other error" do
      error = described_class.new("environment inválido", status_code: nil, error_code: "CONFIG")

      expect(error.message).to eq("environment inválido")
      expect(error.error_code).to eq("CONFIG")
    end
  end

  describe Nfe::InvoiceProcessingError do
    it "is a kind of Nfe::Error" do
      expect(described_class.new("202 sem Location")).to be_a(Nfe::Error)
    end

    it "carries a logging-safe to_h" do
      expect(described_class.new("sem Location").to_h).to include(
        type: "Nfe::InvoiceProcessingError",
        message: "sem Location"
      )
    end
  end
end
