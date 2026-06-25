# frozen_string_literal: true

require "socket"
require "zlib"
require "stringio"

# Minimal canned HTTP/1.1 server backed by stdlib TCPServer (no webrick, no gems).
# Serves a single response per accepted connection, optionally delaying the write
# to exercise read timeouts, then records the raw request it received.
class CannedHttpServer
  attr_reader :port

  def initialize(response:, delay: 0)
    @response = response
    @delay = delay
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.addr[1]
    @requests = Queue.new
    @thread = Thread.new { serve_loop }
  end

  def last_request
    @requests.pop
  end

  def base_url
    "http://127.0.0.1:#{@port}"
  end

  def shutdown
    @thread.kill
    @server.close
  rescue IOError
    # already closed
  end

  private

  def serve_loop
    loop do
      client = @server.accept
      raw = read_request(client)
      @requests << raw
      sleep(@delay) if @delay.positive?
      client.write(@response)
      client.close
    rescue IOError, Errno::ECONNRESET
      next
    end
  end

  def read_request(client)
    request_line = client.gets.to_s
    headers = +""
    while (line = client.gets) && line != "\r\n"
      headers << line
    end
    request_line + headers
  end
end

RSpec.describe Nfe::Http::NetHttp do
  subject(:transport) { described_class.new }

  def gzip(string)
    io = StringIO.new
    gz = Zlib::GzipWriter.new(io)
    gz.write(string)
    gz.close
    io.string
  end

  def http_response(status_line:, headers: {}, body: "")
    head = ["HTTP/1.1 #{status_line}"]
    headers.each { |k, v| head << "#{k}: #{v}" }
    head << "Content-Length: #{body.bytesize}" unless headers.keys.map(&:downcase).include?("content-length")
    head << "Connection: close"
    "#{head.join("\r\n")}\r\n\r\n#{body}"
  end

  def request_for(server, method: "GET", path: "/v1/ping", body: nil, headers: {})
    Nfe::Http::Request.new(
      method: method, base_url: server.base_url, path: path, headers: headers, body: body
    )
  end

  it "performs a basic GET returning 200 and a JSON body" do
    server = CannedHttpServer.new(
      response: http_response(status_line: "200 OK", headers: { "Content-Type" => "application/json" },
                              body: '{"ok":true}')
    )
    response = transport.call(request_for(server))

    expect(response.status).to eq(200)
    expect(response.body).to eq('{"ok":true}')
    expect(response.header("content-type")).to eq("application/json")
  ensure
    server.shutdown
  end

  it "sends POST bodies and the configured headers to the wire" do
    server = CannedHttpServer.new(response: http_response(status_line: "201 Created"))
    transport.call(request_for(server, method: "POST", body: '{"a":1}',
                                       headers: { "X-NFE-APIKEY" => "k123" }))

    raw = server.last_request
    expect(raw).to include("POST /v1/ping")
    expect(raw.downcase).to include("x-nfe-apikey: k123")
  ensure
    server.shutdown
  end

  it "lowercases response header names" do
    server = CannedHttpServer.new(
      response: http_response(status_line: "200 OK", headers: { "X-Request-Id" => "req_9" })
    )
    response = transport.call(request_for(server))

    expect(response.headers).to have_key("x-request-id")
    expect(response.header("X-Request-Id")).to eq("req_9")
  ensure
    server.shutdown
  end

  it "decompresses a gzip body and drops content-encoding/content-length" do
    body = gzip('{"big":"payload"}')
    server = CannedHttpServer.new(
      response: http_response(status_line: "200 OK",
                              headers: { "Content-Encoding" => "gzip" }, body: body)
    )
    response = transport.call(request_for(server))

    expect(response.body).to eq('{"big":"payload"}')
    expect(response.header("content-encoding")).to be_nil
    expect(response.header("content-length")).to be_nil
  ensure
    server.shutdown
  end

  it "defaults Accept-Encoding to gzip when the caller does not set it" do
    server = CannedHttpServer.new(response: http_response(status_line: "200 OK"))
    transport.call(request_for(server))

    expect(server.last_request.downcase).to include("accept-encoding: gzip")
  ensure
    server.shutdown
  end

  it "preserves a 202 and its Location header without following it" do
    server = CannedHttpServer.new(
      response: http_response(status_line: "202 Accepted",
                              headers: { "Location" => "/v1/companies/1/serviceinvoices/9" })
    )
    response = transport.call(request_for(server, method: "POST", body: "{}"))

    expect(response.status).to eq(202)
    expect(response.location).to eq("/v1/companies/1/serviceinvoices/9")
  ensure
    server.shutdown
  end

  it "raises Nfe::TimeoutError when the read times out" do
    server = CannedHttpServer.new(response: http_response(status_line: "200 OK"), delay: 1)
    request = Nfe::Http::Request.new(
      method: "GET", base_url: server.base_url, path: "/slow", read_timeout: 0.2
    )

    expect { transport.call(request) }.to raise_error(Nfe::TimeoutError)
  ensure
    server.shutdown
  end

  it "raises Nfe::ApiConnectionError when the connection is refused" do
    closed = TCPServer.new("127.0.0.1", 0)
    port = closed.addr[1]
    closed.close
    request = Nfe::Http::Request.new(method: "GET", base_url: "http://127.0.0.1:#{port}", path: "/")

    expect { transport.call(request) }.to raise_error(Nfe::ApiConnectionError)
  end

  it "reuses a single pooled connection for the same origin" do
    server = CannedHttpServer.new(response: http_response(status_line: "200 OK"))
    transport.call(request_for(server))
    pool = transport.instance_variable_get(:@pool)

    expect(pool.keys).to eq(["127.0.0.1:#{server.port}"])
    expect(pool.values.first.size).to eq(1)
  ensure
    server.shutdown
  end

  it "enforces TLS VERIFY_PEER for https origins without a real handshake" do
    uri = URI.parse("https://api.nfse.io/v2/ping")
    http = transport.send(:build_connection, uri)

    expect(http.use_ssl?).to be(true)
    expect(http.verify_mode).to eq(OpenSSL::SSL::VERIFY_PEER)
  end

  it "applies an optional ca_file to the https connection" do
    transport = described_class.new(ca_file: "/etc/ssl/custom.pem")
    http = transport.send(:build_connection, URI.parse("https://api.nfse.io"))

    expect(http.ca_file).to eq("/etc/ssl/custom.pem")
  end
end
