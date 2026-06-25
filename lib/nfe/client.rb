# frozen_string_literal: true

require "nfe/configuration"

module Nfe
  # Primary entry point for the SDK.
  #
  #   client = Nfe::Client.new(api_key: "...")
  #   client.service_invoices.create(company_id: "...", data: { ... })
  #
  # Resources are exposed as lazy, memoized snake_case accessors. In this
  # foundation change the accessor bodies are stubs that raise
  # +NotImplementedError+; they are implemented by the
  # add-{entity,invoice,lookup}-resources and add-rtc-invoice-emission changes.
  class Client
    # The 17 core resource accessor names (entity + invoice + lookup families).
    RESOURCES = %i[
      service_invoices
      product_invoices
      consumer_invoices
      transportation_invoices
      inbound_product_invoices
      product_invoice_query
      consumer_invoice_query
      companies
      legal_people
      natural_people
      webhooks
      addresses
      legal_entity_lookup
      natural_person_lookup
      tax_calculation
      tax_codes
      state_taxes
    ].freeze

    attr_reader :config

    def initialize(api_key: nil, data_api_key: nil, environment: :production,
                   base_url: nil, timeout: Configuration::DEFAULT_TIMEOUT,
                   retry_config: nil, configuration: nil)
      @config = configuration || Configuration.new(
        api_key: api_key,
        data_api_key: data_api_key,
        environment: environment,
        timeout: timeout,
        base_url_overrides: base_url ? { main: base_url } : {}
      )
      @retry_config = retry_config
      @resources = {}
    end

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

    private

    def resource(name)
      @resources[name] ||= build_resource(name)
    end

    def build_resource(name)
      raise NotImplementedError,
            "Resource ##{name} is declared in the add-ruby-foundation change but " \
            "implemented in a later change " \
            "(add-{entity,invoice,lookup}-resources / add-rtc-invoice-emission)."
    end
  end
end
