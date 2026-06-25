# frozen_string_literal: true

module Nfe
  # Central configuration for the SDK.
  #
  # The multi-base-URL host map lives here and is the single source of truth —
  # no resource hard-codes a URL. Resources declare an +api_family+ and obtain
  # their host via {#base_url_for}.
  #
  # NOTE: this is the foundation shell. Per-family API key resolution
  # (+api_key_for+), +NFE_API_KEY+/+NFE_DATA_API_KEY+ environment fallback,
  # TLS trust (+ca_file+), +proxy+ and per-call request options are layered on
  # by the add-client-core change.
  class Configuration
    # Host per NFE.io product family. The +/v1+ for the +:main+ family is
    # supplied by each resource's +api_version+, not baked into the host. The
    # +:addresses+ family is the documented exception where +/v2+ is part of
    # the host.
    HOSTS = {
      main: "https://api.nfe.io",
      addresses: "https://address.api.nfe.io/v2",
      "nfe-query": "https://nfe.api.nfe.io",
      "legal-entity": "https://legalentity.api.nfe.io",
      "natural-person": "https://naturalperson.api.nfe.io",
      cte: "https://api.nfse.io"
    }.freeze

    DEFAULT_TIMEOUT = 30
    DEFAULT_OPEN_TIMEOUT = 10
    DEFAULT_MAX_RETRIES = 2

    attr_reader :api_key, :data_api_key, :environment, :timeout, :open_timeout,
                :max_retries, :logger, :user_agent_suffix, :base_url_overrides

    def initialize(api_key: nil, data_api_key: nil, environment: :production,
                   timeout: DEFAULT_TIMEOUT, open_timeout: DEFAULT_OPEN_TIMEOUT,
                   max_retries: DEFAULT_MAX_RETRIES, logger: nil,
                   user_agent_suffix: nil, base_url_overrides: {})
      @api_key = api_key
      @data_api_key = data_api_key
      @environment = environment
      @timeout = timeout
      @open_timeout = open_timeout
      @max_retries = max_retries
      @logger = logger
      @user_agent_suffix = user_agent_suffix
      @base_url_overrides = base_url_overrides
    end

    # Returns the base host for a product +family+. A per-family override (from
    # +base_url_overrides+) wins; an unknown family falls back to the +:main+
    # host as a safe default.
    def base_url_for(family)
      key = normalize_family(family)
      @base_url_overrides[key] || HOSTS[key] || HOSTS.fetch(:main)
    end

    private

    def normalize_family(family)
      family.to_s.tr("_", "-").to_sym
    end
  end
end
