# frozen_string_literal: true

require "date"
require "time"

module Nfe
  # Normalizes date inputs to the canonical +YYYY-MM-DD+ string the lookup APIs
  # expect. Accepts either an already-formatted ISO date string or a Ruby
  # date/time object, and raises {Nfe::InvalidRequestError} (Portuguese-language
  # message) on any malformed, out-of-range, or unsupported input.
  module DateNormalizer
    ISO_DATE = /\A\d{4}-\d{2}-\d{2}\z/

    module_function

    # @param input [String, Date, Time, DateTime]
    # @return [String] the date formatted as +YYYY-MM-DD+.
    # @raise [Nfe::InvalidRequestError] on bad format, out-of-range, or type.
    def to_iso_date(input)
      case input
      when String then from_string(input)
      when Date, Time, DateTime then input.strftime("%Y-%m-%d")
      else
        raise Nfe::InvalidRequestError, "data inválida: tipo não suportado (#{input.class})"
      end
    end

    # @api private
    def from_string(value)
      raise Nfe::InvalidRequestError, "data inválida: use o formato YYYY-MM-DD" unless ISO_DATE.match?(value)

      Date.iso8601(value).strftime("%Y-%m-%d")
    rescue ArgumentError
      raise Nfe::InvalidRequestError, "data inválida: #{value.inspect} está fora do intervalo válido"
    end
  end
end
