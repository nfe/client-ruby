# frozen_string_literal: true

module Nfe
  # Client-side validators for identifiers and document numbers. Each method
  # runs before any HTTP request is issued (fail-fast) and raises
  # {Nfe::InvalidRequestError} with a Portuguese-language message naming the
  # offending argument.
  #
  # Normalizing validators (+access_key+, +cnpj+, +cpf+, +cep+, +state+) return
  # a normalized +String+; CNPJ/CPF/CEP are NEVER coerced to Integer, so future
  # alphanumeric CNPJ (v3) input is preserved.
  module IdValidator
    # The 27 Brazilian UFs plus +EX+ (foreign) and +NA+ (not applicable).
    UF = %w[
      AC AL AP AM BA CE DF ES GO MA MT MS MG PA PB PR PE PI RJ RN RS RO RR SC SP SE TO
      EX NA
    ].freeze

    module_function

    # @return [String] the non-empty company id.
    def company_id(value)
      presence!(value, "company_id")
    end

    # @return [String] the non-empty invoice id.
    def invoice_id(value)
      presence!(value, "invoice_id")
    end

    # @return [String] the non-empty state-tax id.
    def state_tax_id(value)
      presence!(value, "state_tax_id")
    end

    # @return [String] the non-empty event key.
    def event_key(value)
      presence!(value, "event_key")
    end

    # Strips non-digits, validates the 44-digit length, returns the normalized
    # digits-only string.
    #
    # @return [String]
    def access_key(value)
      digits = digits_only(value)
      unless /\A\d{44}\z/.match?(digits)
        raise Nfe::InvalidRequestError, "chave de acesso (access_key) deve conter 44 dígitos"
      end

      digits
    end

    # Normalizes to 14 digits without coercing to Integer (preserves future
    # alphanumeric CNPJ v3).
    #
    # @return [String]
    def cnpj(value)
      normalized = strip_separators(value)
      raise Nfe::InvalidRequestError, "CNPJ (cnpj) deve conter 14 caracteres" unless normalized.length == 14

      normalized
    end

    # @return [String] the 11-digit CPF.
    def cpf(value)
      digits = digits_only(value)
      raise Nfe::InvalidRequestError, "CPF (cpf) deve conter 11 dígitos" unless digits.length == 11

      digits
    end

    # @return [String] the 8-digit CEP.
    def cep(value)
      digits = digits_only(value)
      raise Nfe::InvalidRequestError, "CEP (cep) deve conter 8 dígitos" unless digits.length == 8

      digits
    end

    # @return [String] the validated, uppercased UF.
    def state(value)
      normalized = value.to_s.strip.upcase
      raise Nfe::InvalidRequestError, "estado (state) inválido: #{value.inspect}" unless UF.include?(normalized)

      normalized
    end

    # @api private
    def presence!(value, name)
      string = value.to_s
      raise Nfe::InvalidRequestError, "#{name} não pode ser vazio" if string.strip.empty?

      value
    end

    # @api private
    def digits_only(value)
      value.to_s.gsub(/\D/, "")
    end

    # @api private
    def strip_separators(value)
      value.to_s.gsub(/[^0-9A-Za-z]/, "")
    end
  end
end
