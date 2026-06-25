# frozen_string_literal: true

require "nfe/configuration"
require "nfe/http/net_http"
require "nfe/http/retrying_transport"
require "nfe/http/retry_policy"
require "nfe/http/request"
require "nfe/http/user_agent"
require "nfe/error_factory"

require "nfe/resources/abstract_resource"
require "nfe/resources/service_invoices"
require "nfe/resources/product_invoices"
require "nfe/resources/consumer_invoices"
require "nfe/resources/transportation_invoices"
require "nfe/resources/inbound_product_invoices"
require "nfe/resources/product_invoice_query"
require "nfe/resources/consumer_invoice_query"
require "nfe/resources/companies"
require "nfe/resources/legal_people"
require "nfe/resources/natural_people"
require "nfe/resources/webhooks"
require "nfe/resources/addresses"
require "nfe/resources/legal_entity_lookup"
require "nfe/resources/natural_person_lookup"
require "nfe/resources/tax_calculation"
require "nfe/resources/tax_codes"
require "nfe/resources/state_taxes"
require "nfe/resources/service_invoices_rtc"
require "nfe/resources/product_invoices_rtc"

module Nfe
  # Primary entry point for the SDK.
  #
  #   client = Nfe::Client.new(api_key: "...")
  #   client.service_invoices.create(company_id: "...", data: { ... })
  #
  # Resources are exposed as lazy, memoized snake_case accessors, each guarded
  # by a +Mutex+ so a single +Client+ is safe to share across threads
  # (Rails/Sidekiq/Puma). The class is the public surface and is NOT designed
  # for subclassing; customization is achieved by composing
  # {Nfe::Configuration} and the injected transport.
  class Client
    # The 17 core resource accessor names mapped to their resource classes.
    RESOURCES = {
      service_invoices: Resources::ServiceInvoices,
      product_invoices: Resources::ProductInvoices,
      consumer_invoices: Resources::ConsumerInvoices,
      transportation_invoices: Resources::TransportationInvoices,
      inbound_product_invoices: Resources::InboundProductInvoices,
      product_invoice_query: Resources::ProductInvoiceQuery,
      consumer_invoice_query: Resources::ConsumerInvoiceQuery,
      companies: Resources::Companies,
      legal_people: Resources::LegalPeople,
      natural_people: Resources::NaturalPeople,
      webhooks: Resources::Webhooks,
      addresses: Resources::Addresses,
      legal_entity_lookup: Resources::LegalEntityLookup,
      natural_person_lookup: Resources::NaturalPersonLookup,
      tax_calculation: Resources::TaxCalculation,
      tax_codes: Resources::TaxCodes,
      state_taxes: Resources::StateTaxes,
      # RTC (Reforma Tributária) emission — paridade-plus addons, not part of
      # the 17 canonical resources shared with the PHP/Node SDKs.
      service_invoices_rtc: Resources::ServiceInvoicesRtc,
      product_invoices_rtc: Resources::ProductInvoicesRtc
    }.freeze

    # @return [Nfe::Configuration] the active configuration.
    attr_reader :configuration

    # @param api_key [String, nil] the main API key (overridden by +configuration+).
    # @param data_api_key [String, nil] the data-services API key.
    # @param configuration [Nfe::Configuration, nil] when supplied, the other
    #   convenience keyword arguments are ignored.
    # @param environment [Symbol] :production (default) or :development.
    # @param timeout [Integer] read timeout in seconds.
    # @param max_retries [Integer] retries after the initial attempt.
    # @param logger [#info, #warn, #error, nil]
    # @param user_agent_suffix [String, nil]
    def initialize(api_key: nil, data_api_key: nil, configuration: nil,
                   environment: :production, timeout: 30, max_retries: 3,
                   logger: nil, user_agent_suffix: nil)
      @configuration = configuration || Configuration.new(
        api_key: api_key,
        data_api_key: data_api_key,
        environment: environment,
        timeout: timeout,
        max_retries: max_retries,
        logger: logger,
        user_agent_suffix: user_agent_suffix
      )
      @resources = {}
      @transports = {}
      @resource_mutex = Mutex.new
      @transport_mutex = Mutex.new
    end

    # Lazy, thread-safe, memoized resource accessors (each built once under a Mutex).
    def service_invoices = resource(:service_invoices)
    def product_invoices = resource(:product_invoices)
    def consumer_invoices = resource(:consumer_invoices)
    def transportation_invoices = resource(:transportation_invoices)
    def inbound_product_invoices = resource(:inbound_product_invoices)
    def product_invoice_query = resource(:product_invoice_query)
    def consumer_invoice_query = resource(:consumer_invoice_query)
    def companies = resource(:companies)
    def legal_people = resource(:legal_people)
    def natural_people = resource(:natural_people)
    def webhooks = resource(:webhooks)
    def addresses = resource(:addresses)
    def legal_entity_lookup = resource(:legal_entity_lookup)
    def natural_person_lookup = resource(:natural_person_lookup)
    def tax_calculation = resource(:tax_calculation)
    def tax_codes = resource(:tax_codes)
    def state_taxes = resource(:state_taxes)
    def service_invoices_rtc = resource(:service_invoices_rtc)
    def product_invoices_rtc = resource(:product_invoices_rtc)

    # Issue an arbitrary request against +family+, applying the family's host
    # and key plus the standard authorization and User-Agent headers. This is
    # the low-level escape hatch shared by every resource.
    #
    # When +request_options+ is supplied, its non-nil +api_key+, +base_url+, and
    # +timeout+ override the family-resolved values for this single call (enabling
    # multi-tenant per-call keys); nil fields fall back to family resolution.
    #
    # Raises the appropriate {Nfe::Error} subclass (via {Nfe::ErrorFactory}) on a
    # non-2xx response (note: 202 is a success); otherwise returns the
    # {Nfe::Http::Response}.
    #
    # @api private
    def request(method, family:, path:, query: {}, body: nil, headers: {},
                idempotency_key: nil, request_options: nil)
      request = build_request(method, family: family, path: path, query: query,
                                      body: body, headers: headers,
                                      idempotency_key: idempotency_key,
                                      request_options: request_options)

      response = transport_for(family).call(request)
      raise Nfe::ErrorFactory.from_response(response) unless response.success?

      response
    end

    private

    # Compose the {Nfe::Http::Request}, resolving host/key/timeout from the
    # family (with per-call +request_options+ overrides) and applying the
    # standard headers.
    def build_request(method, family:, path:, query:, body:, headers:,
                      idempotency_key:, request_options:)
      base_url = request_options&.base_url || configuration.base_url_for(family)
      api_key = request_options&.api_key || configuration.api_key_for(family)

      Http::Request.new(
        method: method.to_s.upcase,
        base_url: base_url,
        path: path,
        headers: default_headers(api_key).merge(headers),
        query: query,
        body: body,
        open_timeout: configuration.open_timeout,
        read_timeout: request_options&.timeout || configuration.timeout,
        idempotency_key: idempotency_key
      )
    end

    # Standard headers applied to every outgoing request.
    def default_headers(api_key)
      {
        "X-NFE-APIKEY" => api_key,
        "User-Agent" => Http::UserAgent.build(configuration.user_agent_suffix),
        "Accept" => "application/json"
      }
    end

    # Memoize (under a Mutex) the resource instance for +name+.
    def resource(name)
      @resource_mutex.synchronize do
        @resources[name] ||= RESOURCES.fetch(name).new(self)
      end
    end

    # Memoize (under a Mutex) a RetryingTransport(NetHttp) per family. Families
    # may differ in nothing transport-wise today, but memoizing per family keeps
    # the door open for per-host tuning and matches the canonical contract.
    def transport_for(family)
      @transport_mutex.synchronize do
        @transports[family] ||= build_transport
      end
    end

    def build_transport
      inner = Http::NetHttp.new(
        default_open_timeout: configuration.open_timeout,
        default_read_timeout: configuration.timeout,
        ca_file: configuration.ca_file
      )
      policy = Http::RetryPolicy.new(
        max_retries: configuration.max_retries,
        base_delay: 1.0,
        max_delay: 30.0,
        jitter: 0.3
      )
      Http::RetryingTransport.new(inner: inner, policy: policy,
                                  logger: configuration.logger)
    end
  end
end
