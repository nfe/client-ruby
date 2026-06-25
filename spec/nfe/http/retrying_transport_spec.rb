# frozen_string_literal: true

RSpec.describe Nfe::Http::RetryingTransport do
  # Capture every requested sleep duration instead of really sleeping.
  let(:slept) { [] }
  let(:sleep_fn) { ->(seconds) { slept << seconds } }
  let(:fake) { FakeTransport.new }

  def get_request(idempotency_key: nil)
    Nfe::Http::Request.new(
      method: "GET",
      base_url: "https://api.nfse.io",
      path: "/v2/companies/abc/productinvoices",
      headers: { "X-NFE-APIKEY" => "secret-key", "Accept" => "application/json" },
      idempotency_key: idempotency_key
    )
  end

  def post_request(idempotency_key: nil)
    Nfe::Http::Request.new(
      method: "POST",
      base_url: "https://api.nfse.io",
      path: "/v2/companies/abc/productinvoices",
      headers: { "X-NFE-APIKEY" => "secret-key" },
      body: "{}",
      idempotency_key: idempotency_key
    )
  end

  def response(status, headers: {}, body: nil)
    Nfe::Http::Response.new(status: status, headers: headers, body: body)
  end

  def transport(policy: Nfe::Http::RetryPolicy.default, logger: nil)
    described_class.new(inner: fake, policy: policy, sleep_fn: sleep_fn, logger: logger)
  end

  describe "#retryable_status?" do
    subject(:decorator) { transport }

    it "treats 429 and 5xx as retryable, others as not" do
      expect(decorator.retryable_status?(429)).to be(true)
      expect(decorator.retryable_status?(500)).to be(true)
      expect(decorator.retryable_status?(599)).to be(true)
      expect(decorator.retryable_status?(400)).to be(false)
      expect(decorator.retryable_status?(200)).to be(false)
    end
  end

  it "transparently returns 200 after 503 -> 503 -> 200 on a GET" do
    fake.enqueue(response(503)).enqueue(response(503)).enqueue(response(200, body: "ok"))

    result = transport.call(get_request)

    expect(result.status).to eq(200)
    expect(fake.call_count).to eq(3)
    expect(slept.length).to eq(2)
  end

  it "does not retry a 400 client error" do
    fake.enqueue(response(400))

    result = transport.call(get_request)

    expect(result.status).to eq(400)
    expect(fake.call_count).to eq(1)
    expect(slept).to be_empty
  end

  it "returns the last 503 once retries are exhausted" do
    fake.enqueue(response(503))

    result = transport.call(get_request)

    expect(result.status).to eq(503)
    # default policy: 1 initial + 3 retries = 4 attempts
    expect(fake.call_count).to eq(4)
    expect(slept.length).to eq(3)
  end

  it "honors an integer Retry-After header (waits >= 5s)" do
    fake.enqueue(response(429, headers: { "retry-after" => "5" })).enqueue(response(200))

    transport.call(get_request)

    expect(slept.first).to be >= 5
  end

  it "clamps Retry-After to max_delay" do
    policy = Nfe::Http::RetryPolicy.new(max_retries: 2, base_delay: 1.0, max_delay: 3.0, jitter: 0.0)
    fake.enqueue(response(429, headers: { "retry-after" => "999" })).enqueue(response(200))

    transport(policy: policy).call(get_request)

    expect(slept.first).to eq(3.0)
  end

  it "does not retry a POST without an idempotency key" do
    fake.enqueue(response(503))

    result = transport.call(post_request)

    expect(result.status).to eq(503)
    expect(fake.call_count).to eq(1)
    expect(slept).to be_empty
  end

  it "retries a POST that carries an idempotency key" do
    fake.enqueue(response(503)).enqueue(response(201))

    result = transport.call(post_request(idempotency_key: "9f1c-key"))

    expect(result.status).to eq(201)
    expect(fake.call_count).to eq(2)
  end

  it "retries a network error then propagates it after exhaustion" do
    fake.enqueue(Nfe::ApiConnectionError.new("boom"))

    expect { transport.call(get_request) }.to raise_error(Nfe::ApiConnectionError)
    expect(fake.call_count).to eq(4)
    expect(slept.length).to eq(3)
  end

  it "retries a timeout (subclass of ApiConnectionError) then succeeds" do
    fake.enqueue(Nfe::TimeoutError.new("slow")).enqueue(response(200))

    result = transport.call(get_request)

    expect(result.status).to eq(200)
    expect(fake.call_count).to eq(2)
  end

  it "does not retry a network error on a non-idempotent POST" do
    fake.enqueue(Nfe::ApiConnectionError.new("boom"))

    expect { transport.call(post_request) }.to raise_error(Nfe::ApiConnectionError)
    expect(fake.call_count).to eq(1)
    expect(slept).to be_empty
  end

  it "makes exactly one attempt under RetryPolicy.none" do
    fake.enqueue(response(503))

    result = transport(policy: Nfe::Http::RetryPolicy.none).call(get_request)

    expect(result.status).to eq(503)
    expect(fake.call_count).to eq(1)
  end

  describe "logging" do
    # Duck-typed logger: any object responding to info/warn/error. Using a
    # plain double keeps the SDK free of a Logger runtime dependency.
    let(:logger) { double("DuckLogger", info: nil, warn: nil, error: nil) }

    it "warns on each retry and errors on final failure with redacted headers" do
      fake.enqueue(response(503))

      transport(logger: logger).call(get_request)

      expect(logger).to have_received(:warn).exactly(3).times
      expect(logger).to have_received(:error).once
    end

    it "redacts the API key and never logs the body in the start info line" do
      captured = []
      allow(logger).to receive(:info) { |line| captured << line }
      fake.enqueue(response(200, body: "sensitive-body-12345678901"))

      transport(logger: logger).call(get_request)

      line = captured.join("\n")
      expect(line).to include("[REDACTED]")
      expect(line).not_to include("secret-key")
      expect(line).not_to include("sensitive-body")
    end

    it "logs error on a network failure without raising from logging" do
      fake.enqueue(Nfe::ApiConnectionError.new("boom"))

      expect { transport(logger: logger).call(get_request) }.to raise_error(Nfe::ApiConnectionError)
      expect(logger).to have_received(:error).once
    end

    it "never lets a raising logger break the request" do
      allow(logger).to receive(:warn).and_raise(StandardError, "logger down")
      allow(logger).to receive(:error).and_raise(StandardError, "logger down")
      fake.enqueue(response(503)).enqueue(response(200))

      result = transport(logger: logger).call(get_request)

      expect(result.status).to eq(200)
    end

    it "does not log when no logger is configured" do
      fake.enqueue(response(503)).enqueue(response(200))

      expect { transport.call(get_request) }.not_to raise_error
    end
  end

  describe "per-call isolation" do
    it "does not let one call's outcome affect a concurrent call" do
      fake_a = FakeTransport.new.enqueue(response(503)).enqueue(response(200))
      fake_b = FakeTransport.new.enqueue(response(200))

      decorator_a = described_class.new(inner: fake_a, sleep_fn: sleep_fn)
      decorator_b = described_class.new(inner: fake_b, sleep_fn: sleep_fn)

      result_b = decorator_b.call(get_request)
      result_a = decorator_a.call(get_request)

      expect(result_b.status).to eq(200)
      expect(fake_b.call_count).to eq(1)
      expect(result_a.status).to eq(200)
      expect(fake_a.call_count).to eq(2)
    end
  end
end
