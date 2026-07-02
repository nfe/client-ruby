# frozen_string_literal: true

# Minimal stand-in for Nfe::Http::Response, keeping this spec self-contained.
# Mirrors its contract: lowercase header keys and case-insensitive #header.
StubResponse = Struct.new(:status, :headers, :body) do
  def header(name)
    headers[name.downcase]
  end
end

RSpec.describe Nfe::ErrorFactory do
  def response(status, body: nil, headers: {})
    StubResponse.new(status, headers, body)
  end

  describe ".from_response status mapping" do
    {
      400 => Nfe::InvalidRequestError,
      401 => Nfe::AuthenticationError,
      403 => Nfe::AuthorizationError,
      404 => Nfe::NotFoundError,
      409 => Nfe::ConflictError,
      422 => Nfe::InvalidRequestError,
      429 => Nfe::RateLimitError,
      500 => Nfe::ServerError,
      502 => Nfe::ServerError,
      599 => Nfe::ServerError
    }.each do |status, klass|
      it "maps HTTP #{status} to #{klass}" do
        error = described_class.from_response(response(status))

        expect(error).to be_a(klass)
        expect(error.status_code).to eq(status)
      end
    end

    it "falls back to InvalidRequestError for an unmapped 4xx (e.g. 418)" do
      expect(described_class.from_response(response(418))).to be_a(Nfe::InvalidRequestError)
    end

    it "falls back to ServerError for an unmapped >= 500" do
      expect(described_class.from_response(response(600))).to be_a(Nfe::ServerError)
    end
  end

  describe ".from_response body extraction" do
    it "extracts message, error_code, and request_id" do
      body = '{"message":"CNPJ inválido","code":"INVALID_CNPJ"}'
      error = described_class.from_response(
        response(422, body: body, headers: { "x-request-id" => "req_123" })
      )

      expect(error.message).to eq("CNPJ inválido")
      expect(error.error_code).to eq("INVALID_CNPJ")
      expect(error.request_id).to eq("req_123")
    end

    it "falls back to x-correlation-id for the request id" do
      error = described_class.from_response(
        response(500, headers: { "x-correlation-id" => "corr_9" })
      )

      expect(error.request_id).to eq("corr_9")
    end

    it "reads the message from alternate keys (error/detail/details)" do
      expect(described_class.from_response(response(400, body: '{"error":"e1"}')).message).to eq("e1")
      expect(described_class.from_response(response(400, body: '{"detail":"d1"}')).message).to eq("d1")
      expect(described_class.from_response(response(400, body: '{"details":"d2"}')).message).to eq("d2")
    end

    it "reads the message from a string errors field" do
      expect(described_class.from_response(response(400, body: '{"errors":"oops"}')).message).to eq("oops")
    end

    it "reads the message from an array errors field" do
      expect(described_class.from_response(response(400, body: '{"errors":["first","second"]}')).message)
        .to eq("first")
    end

    it "reads the message from an array of error objects" do
      body = '{"errors":[{"message":"nested"}]}'
      expect(described_class.from_response(response(400, body: body)).message).to eq("nested")
    end

    it "coerces an integer error code to a string" do
      expect(described_class.from_response(response(400, body: '{"code":42}')).error_code).to eq("42")
    end

    it "uses a default message when the body has none" do
      expect(described_class.from_response(response(503)).message).to eq("API request failed with HTTP 503")
    end

    it "preserves the raw body and headers on the error" do
      headers = { "x-request-id" => "r1", "content-type" => "application/json" }
      error = described_class.from_response(response(404, body: '{"message":"x"}', headers: headers))

      expect(error.response_body).to eq('{"message":"x"}')
      expect(error.response_headers).to eq(headers)
    end
  end

  describe ".from_response resilience" do
    it "does not crash on a non-JSON body and still returns the right class" do
      error = described_class.from_response(response(500, body: "<html>oops</html>"))

      expect(error).to be_a(Nfe::ServerError)
      expect(error.message).to eq("API request failed with HTTP 500")
    end

    it "tolerates an empty body" do
      expect { described_class.from_response(response(400, body: "")) }.not_to raise_error
    end

    it "tolerates a JSON array (non-Hash) body" do
      error = described_class.from_response(response(400, body: "[1,2,3]"))
      expect(error.message).to eq("API request failed with HTTP 400")
    end
  end

  describe ".from_response rate limiting" do
    it "populates retry_after from the Retry-After header" do
      error = described_class.from_response(response(429, headers: { "retry-after" => "30" }))

      expect(error).to be_a(Nfe::RateLimitError)
      expect(error.retry_after).to eq(30)
    end

    it "leaves retry_after nil when the header is absent or non-numeric" do
      expect(described_class.from_response(response(429)).retry_after).to be_nil
      expect(described_class.from_response(response(429, headers: { "retry-after" => "soon" })).retry_after)
        .to be_nil
    end
  end

  describe ".from_response message hardening" do
    it "caps an oversized message and appends an ellipsis" do
      long = "a" * 1000
      error = described_class.from_response(response(400, body: { message: long }.to_json))

      expect(error.message.length).to eq(described_class::MAX_MESSAGE_LENGTH + 3)
      expect(error.message).to end_with("...")
    end

    it "scrubs control characters from the message" do
      raw = "line1\e[31mred\u0000end"
      error = described_class.from_response(response(400, body: { message: raw }.to_json))

      expect(error.message).not_to match(/[\x00-\x1f\x7f]/)
      expect(error.message).to include("line1")
      expect(error.message).to include("end")
    end

    it "drops a message that is only control characters and uses the default" do
      raw = "\u0000\u0001\u0002"
      error = described_class.from_response(response(400, body: { message: raw }.to_json))

      expect(error.message).to eq("API request failed with HTTP 400")
    end
  end

  describe ".from_network_error" do
    it "maps Net::OpenTimeout to TimeoutError" do
      error = described_class.from_network_error(Net::OpenTimeout.new("open timed out"))

      expect(error).to be_a(Nfe::TimeoutError)
      expect(error.cause).to be_a(Net::OpenTimeout)
    end

    it "maps Net::ReadTimeout to TimeoutError" do
      expect(described_class.from_network_error(Net::ReadTimeout.new)).to be_a(Nfe::TimeoutError)
    end

    it "maps Timeout::Error to TimeoutError" do
      expect(described_class.from_network_error(Timeout::Error.new("t"))).to be_a(Nfe::TimeoutError)
    end

    it "maps a connection refused to ApiConnectionError (not a timeout)" do
      error = described_class.from_network_error(Errno::ECONNREFUSED.new)

      expect(error).to be_a(Nfe::ApiConnectionError)
      expect(error).not_to be_a(Nfe::TimeoutError)
    end

    it "maps SocketError to ApiConnectionError preserving the cause" do
      original = SocketError.new("getaddrinfo failed")
      error = described_class.from_network_error(original)

      expect(error).to be_a(Nfe::ApiConnectionError)
      expect(error.cause).to eq(original)
    end

    it "maps an OpenSSL TLS error to ApiConnectionError" do
      expect(described_class.from_network_error(OpenSSL::SSL::SSLError.new("tls"))).to be_a(Nfe::ApiConnectionError)
    end
  end
end
