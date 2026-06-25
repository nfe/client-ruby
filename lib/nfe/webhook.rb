# frozen_string_literal: true

require "openssl"
require "json"

module Nfe
  # Stateless helpers for verifying NFE.io webhook deliveries. This is the
  # canonical signature-verification API: it needs no {Nfe::Client}, reads no
  # {Nfe::Configuration}, and performs no network access — the caller supplies
  # the raw payload bytes, the +X-Hub-Signature+ header value, and the secret.
  #
  # == IMPORTANT: pass the RAW request body bytes
  # NFE.io signs the exact bytes it delivered. Read the raw body BEFORE parsing
  # JSON (e.g. +request.body.read+ in Rack/Rails) and pass those bytes. Do NOT
  # re-serialize a parsed object (+payload.to_json+) — key order and whitespace
  # will differ from the signed bytes and verification will fail unpredictably.
  #
  #   raw = request.body.read
  #   sig = request.get_header("HTTP_X_HUB_SIGNATURE")
  #   if Nfe::Webhook.verify_signature(payload: raw, signature: sig, secret: ENV["NFE_WEBHOOK_SECRET"])
  #     event = Nfe::Webhook.construct_event(payload: raw, signature: sig, secret: ENV["NFE_WEBHOOK_SECRET"])
  #     # event.id => dedupe on this; NFE.io sends no timestamp/nonce, so a valid
  #     # signature proves authenticity but NOT freshness. Handlers MUST be
  #     # idempotent and dedupe on the event/invoice id.
  #   end
  #
  # Only the +X-Hub-Signature+ + HMAC-SHA1 scheme is supported. The legacy
  # +X-NFe-Signature+ / HMAC-SHA256 scheme is intentionally NOT implemented; a
  # +sha256=+ header is rejected.
  module Webhook
    # Wire prefix on the +X-Hub-Signature+ header value.
    SIGNATURE_PREFIX = "sha1="
    private_constant :SIGNATURE_PREFIX

    # HMAC-SHA1 hex digests are always 40 lowercase hex characters.
    HEX_RE = /\A[a-f0-9]{40}\z/
    private_constant :HEX_RE

    module_function

    # Verify an +X-Hub-Signature+ value against the payload and secret using
    # constant-time comparison. Returns +true+ only on an exact HMAC-SHA1 match.
    #
    # Never raises: any missing, malformed, wrong-algorithm, wrong-length, or
    # non-hex input yields +false+.
    #
    # @param payload [String] the raw, byte-exact request body.
    # @param signature [String, Array<String>, nil] the +X-Hub-Signature+ value;
    #   a single-element Array (repeated-header shape) uses its first element.
    # @param secret [String, nil] the webhook secret.
    # @return [Boolean]
    def verify_signature(payload:, signature:, secret:)
      return false if secret.nil? || secret.to_s.empty?

      signature = signature.first if signature.is_a?(Array)
      return false if signature.nil?

      signature = signature.to_s
      return false if signature.empty?
      return false unless signature[0, SIGNATURE_PREFIX.length].to_s.downcase == SIGNATURE_PREFIX

      received = signature[SIGNATURE_PREFIX.length..].to_s.downcase
      return false unless HEX_RE.match?(received)

      expected = OpenSSL::HMAC.hexdigest("SHA1", secret, payload.to_s)
      OpenSSL.secure_compare(received, expected)
    rescue StandardError
      false
    end

    # Verify, then parse and unwrap a delivery into a {Nfe::WebhookEvent}.
    #
    # @param payload [String] the raw, byte-exact request body.
    # @param signature [String, Array<String>, nil] the +X-Hub-Signature+ value.
    # @param secret [String, nil] the webhook secret.
    # @return [Nfe::WebhookEvent]
    # @raise [Nfe::SignatureVerificationError] when the signature does not match
    #   or the payload is not valid JSON.
    def construct_event(payload:, signature:, secret:)
      unless verify_signature(payload: payload, signature: signature, secret: secret)
        raise Nfe::SignatureVerificationError, "Assinatura de webhook inválida."
      end

      decoded = parse_payload(payload)
      build_event(decoded)
    end

    # @api private
    def parse_payload(payload)
      decoded = JSON.parse(payload.to_s)
      unless decoded.is_a?(Hash)
        raise Nfe::SignatureVerificationError, "Payload de webhook não decodificou para um objeto."
      end

      decoded
    rescue JSON::ParserError
      raise Nfe::SignatureVerificationError, "Payload de webhook não é JSON válido."
    end

    # Unwrap the +action+/+payload+ or +event+/+data+ envelope into a
    # {Nfe::WebhookEvent}; falls back to a flat +type+/+event_type+/+action+
    # shape carrying the whole body as +data+.
    #
    # @api private
    def build_event(decoded)
      type = first_string(decoded, "action", "event", "type", "event_type")
      data = envelope_data(decoded)

      Nfe::WebhookEvent.new(
        type: type,
        data: data,
        id: nullable_string(decoded["id"] || data["id"]),
        created_at: nullable_string(decoded["createdAt"] || data["createdAt"])
      )
    end

    # @api private
    def envelope_data(decoded)
      candidate = decoded["payload"] || decoded["data"]
      candidate.is_a?(Hash) ? candidate : decoded
    end

    # @api private
    def first_string(hash, *keys)
      keys.each do |key|
        value = hash[key]
        return value if value.is_a?(String) && !value.empty?
      end
      nil
    end

    # @api private
    def nullable_string(value)
      value.is_a?(String) ? value : nil
    end
  end
end
