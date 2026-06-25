# frozen_string_literal: true

module Nfe
  # Central configuration for the SDK and the single source of truth for the
  # multi-base-URL host map. No resource hard-codes a URL: resources declare an
  # +api_family+ and obtain their host via {#base_url_for}.
  #
  # == Two-key model
  # The SDK uses two API keys. The "data" families ({#api_key_for} maps
  # +:addresses+, +:legal_entity+, +:natural_person+ and +:nfe_query+ to it)
  # use +data_api_key+ when present, falling back to +api_key+. Every other
  # family uses +api_key+. Either key may be supplied explicitly or via the
  # +NFE_API_KEY+ / +NFE_DATA_API_KEY+ environment variables (explicit wins).
  #
  # == Environment selects the key, not the URL
  # +:production+ and +:development+ target the SAME endpoints; the active
  # environment is differentiated by the API key in use, not by a distinct base
  # URL. There is no "sandbox URL".
  #
  # == TLS trust
  # +ca_file+ (and optionally +ca_path+) is the ONLY override of the TLS trust
  # store and can only ADD/replace a CA bundle used to verify the peer. There is
  # deliberately NO public API to disable peer verification (no +VERIFY_NONE+,
  # no +insecure_ssl+). The upstream +insecureSsl+ attribute is a server-side
  # property of a webhook delivery target, not the SDK's outbound TLS config.
  class Configuration
    # Host per NFE.io product family, keyed by the canonical (hyphenated)
    # family symbol. The +/v1+ for the +:main+ family is supplied by each
    # resource's +api_version+, not baked into the host. The +:addresses+
    # family is the documented exception where +/v2+ is part of the host.
    HOSTS = {
      main: "https://api.nfe.io",
      addresses: "https://address.api.nfe.io/v2",
      "nfe-query": "https://nfe.api.nfe.io",
      "legal-entity": "https://legalentity.api.nfe.io",
      "natural-person": "https://naturalperson.api.nfe.io",
      cte: "https://api.nfse.io"
    }.freeze

    # Maps family aliases (the snake_case names resources declare) to a
    # canonical family key in {HOSTS}. Keys here are already hyphen-normalized.
    FAMILY_ALIASES = {
      companies: :main,
      "service-invoices": :main,
      "legal-people": :main,
      "natural-people": :main,
      webhooks: :main,
      transportation: :cte,
      "transportation-invoices": :cte,
      "inbound-product": :cte,
      "inbound-product-invoices": :cte,
      "product-invoices": :cte,
      "consumer-invoices": :cte,
      "tax-calculation": :cte,
      "tax-codes": :cte,
      "state-taxes": :cte,
      "product-invoice-query": :"nfe-query",
      "consumer-invoice-query": :"nfe-query"
    }.freeze

    # Canonical families whose key resolves from +data_api_key+ first.
    DATA_FAMILIES = %i[addresses legal-entity natural-person nfe-query].freeze

    # Environments the SDK accepts. Both share the same endpoints.
    VALID_ENVIRONMENTS = %i[production development].freeze

    DEFAULT_TIMEOUT = 30
    DEFAULT_OPEN_TIMEOUT = 10
    DEFAULT_MAX_RETRIES = 3

    attr_reader :api_key, :data_api_key, :environment, :timeout, :open_timeout,
                :max_retries, :logger, :user_agent_suffix, :base_url_overrides,
                :ca_file, :ca_path, :proxy

    # @param api_key [String, nil] main key; falls back to +NFE_API_KEY+.
    # @param data_api_key [String, nil] data-services key; falls back to
    #   +NFE_DATA_API_KEY+.
    # @param environment [Symbol] +:production+ (default) or +:development+.
    # @param timeout [Integer] read timeout in seconds (must be positive).
    # @param open_timeout [Integer] connect timeout in seconds (must be positive).
    # @param max_retries [Integer] retry budget (non-negative).
    # @param logger [Object, nil] optional logger.
    # @param user_agent_suffix [String, nil] appended to the SDK User-Agent.
    # @param base_url_overrides [Hash{Symbol=>String}] per-family escape hatch.
    # @param ca_file [String, nil] path to a CA bundle to ADD to the trust store.
    # @param ca_path [String, nil] directory of CA certs to ADD to the trust store.
    # @param proxy [String, URI, nil] passed through to +Net::HTTP+.
    # @raise [Nfe::ConfigurationError] on invalid values.
    def initialize(api_key: nil, data_api_key: nil, environment: :production,
                   timeout: DEFAULT_TIMEOUT, open_timeout: DEFAULT_OPEN_TIMEOUT,
                   max_retries: DEFAULT_MAX_RETRIES, logger: nil,
                   user_agent_suffix: nil, base_url_overrides: {},
                   ca_file: nil, ca_path: nil, proxy: nil)
      @api_key = resolve_key(api_key, "NFE_API_KEY")
      @data_api_key = resolve_key(data_api_key, "NFE_DATA_API_KEY")
      @environment = environment
      @timeout = timeout
      @open_timeout = open_timeout
      @max_retries = max_retries
      @logger = logger
      @user_agent_suffix = user_agent_suffix
      @base_url_overrides = base_url_overrides || {}
      @ca_file = ca_file
      @ca_path = ca_path
      @proxy = proxy

      validate!
    end

    # Returns the base host for a product +family+. A per-family override (from
    # +base_url_overrides+) wins; an unknown family falls back to the +:main+
    # host as a safe default.
    #
    # @param family [Symbol, String] family or alias (snake_case accepted).
    # @return [String]
    def base_url_for(family)
      canonical = canonical_family(family)
      override = @base_url_overrides[canonical] || @base_url_overrides[family.to_sym]
      override || HOSTS[canonical] || HOSTS.fetch(:main)
    end

    # Resolves the API key for a +family+ under the two-key model. Data families
    # prefer +data_api_key+ and fall back to +api_key+; all other families use
    # +api_key+.
    #
    # @param family [Symbol, String] family or alias (snake_case accepted).
    # @return [String] the resolved key.
    # @raise [Nfe::ConfigurationError] when no key resolves for the family.
    def api_key_for(family)
      canonical = canonical_family(family)
      key = if DATA_FAMILIES.include?(canonical)
              @data_api_key || @api_key
            else
              @api_key
            end
      return key unless key.nil? || key.empty?

      raise Nfe::ConfigurationError,
            "Nenhuma chave de API configurada para a família \"#{canonical}\". " \
            "Informe api_key (ou data_api_key para famílias de dados)."
    end

    private

    # Applies the ENV fallback: an explicit, non-empty argument always wins;
    # otherwise the environment variable (when present) is adopted.
    def resolve_key(explicit, env_name)
      return explicit unless explicit.nil? || explicit.to_s.empty?

      env_value = ENV.fetch(env_name, nil)
      return env_value unless env_value.nil? || env_value.empty?

      explicit
    end

    def validate!
      unless VALID_ENVIRONMENTS.include?(@environment)
        raise Nfe::ConfigurationError,
              "environment inválido: #{@environment.inspect}. " \
              "Use :production ou :development."
      end

      if blank?(@api_key) && blank?(@data_api_key)
        raise Nfe::ConfigurationError,
              "É necessário informar uma api_key (ou data_api_key). " \
              "Defina o argumento ou a variável de ambiente NFE_API_KEY/NFE_DATA_API_KEY."
      end

      validate_positive!(:timeout, @timeout)
      validate_positive!(:open_timeout, @open_timeout)

      return unless !@max_retries.is_a?(Integer) || @max_retries.negative?

      raise Nfe::ConfigurationError,
            "max_retries deve ser um inteiro não negativo, recebido #{@max_retries.inspect}."
    end

    def validate_positive!(name, value)
      return if value.is_a?(Numeric) && value.positive?

      raise Nfe::ConfigurationError,
            "#{name} deve ser um número positivo, recebido #{value.inspect}."
    end

    def blank?(value)
      value.nil? || value.to_s.empty?
    end

    # Normalizes a family/alias into its canonical (hyphenated) family symbol.
    def canonical_family(family)
      normalized = family.to_s.tr("_", "-").to_sym
      return normalized if HOSTS.key?(normalized)

      FAMILY_ALIASES.fetch(normalized, normalized)
    end
  end
end
