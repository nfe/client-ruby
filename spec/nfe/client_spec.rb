# frozen_string_literal: true

RSpec.describe Nfe::Client do
  subject(:client) { described_class.new(api_key: "key") }

  # Inject a request-capturing fake transport in place of the real Net::HTTP
  # stack, so #request can be exercised without network.
  def with_fake_transport(target, response: Nfe::Http::Response.new(status: 200, body: "{}"))
    fake = FakeTransport.new([response])
    allow(target).to receive(:build_transport).and_return(fake)
    fake
  end

  describe "construction" do
    it "instantiates with an API key and exposes its configuration" do
      expect(client).to be_a(described_class)
      expect(client.configuration).to be_a(Nfe::Configuration)
      expect(client.configuration.api_key).to eq("key")
    end

    it "accepts an injected configuration and ignores convenience args" do
      configuration = Nfe::Configuration.new(api_key: "k", timeout: 120)
      built = described_class.new(configuration: configuration, timeout: 5)
      expect(built.configuration).to be(configuration)
      expect(built.configuration.timeout).to eq(120)
    end
  end

  describe "resource accessors" do
    it "declares nineteen resource accessors (17 canonical + 2 RTC addons)" do
      expect(described_class::RESOURCES.size).to eq(19)
    end

    it "returns the right resource class for each accessor" do
      described_class::RESOURCES.each do |name, klass|
        expect(client.public_send(name)).to be_a(klass)
      end
    end

    it "memoizes each accessor (same instance on repeat reads)" do
      first = client.companies
      expect(client.companies).to be(first)
    end
  end

  describe "two-key model" do
    it "serves a data-family resource with only a data_api_key" do
      data_client = described_class.new(data_api_key: "data")
      fake = with_fake_transport(data_client)

      data_client.request(:get, family: :addresses, path: "/addresses/01310100")

      expect(fake.requests.last.headers["X-NFE-APIKEY"]).to eq("data")
    end

    it "raises ConfigurationError when a main-family request has no main key" do
      data_client = described_class.new(data_api_key: "data")
      with_fake_transport(data_client)

      expect { data_client.request(:get, family: :main, path: "/v1/companies") }
        .to raise_error(Nfe::ConfigurationError)
    end
  end

  describe "#request" do
    it "applies host, key, User-Agent and Accept headers" do
      fake = with_fake_transport(client)
      client.request(:get, family: :main, path: "/v1/companies")

      sent = fake.requests.last
      expect(sent.base_url).to eq("https://api.nfe.io")
      expect(sent.path).to eq("/v1/companies")
      expect(sent.headers["X-NFE-APIKEY"]).to eq("key")
      expect(sent.headers["Accept"]).to eq("application/json")
      expect(sent.headers["User-Agent"]).to include(Nfe::VERSION)
    end

    it "includes the configured user_agent_suffix in the User-Agent" do
      suffixed = described_class.new(api_key: "key", user_agent_suffix: "my-app/2.1")
      fake = with_fake_transport(suffixed)
      suffixed.request(:get, family: :main, path: "/v1/companies")

      ua = fake.requests.last.headers["User-Agent"]
      expect(ua).to include(Nfe::VERSION)
      expect(ua).to include("my-app/2.1")
    end

    it "raises a typed error on a non-2xx response" do
      with_fake_transport(client, response: Nfe::Http::Response.new(status: 404, body: "{}"))
      expect { client.request(:get, family: :main, path: "/v1/missing") }
        .to raise_error(Nfe::NotFoundError)
    end

    it "treats 202 as success and returns the response" do
      with_fake_transport(client, response: Nfe::Http::Response.new(status: 202))
      response = client.request(:post, family: :main, path: "/v1/companies/x/invoices")
      expect(response.status).to eq(202)
    end
  end

  describe "thread safety" do
    it "returns one shared instance to concurrent first readers" do
      shared = described_class.new(api_key: "key")
      results = Queue.new

      threads = Array.new(16) do
        Thread.new { results << shared.companies }
      end
      threads.each(&:join)

      instances = []
      instances << results.pop until results.empty?
      expect(instances.uniq.size).to eq(1)
    end
  end
end
