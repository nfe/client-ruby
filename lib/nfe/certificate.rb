# frozen_string_literal: true

require "openssl"
require "time"

module Nfe
  # Metadata extracted from a digital certificate (A1 PKCS#12) parsed locally.
  # +not_before+ / +not_after+ are +Time+ instances; +serial_number+ is a
  # decimal +String+.
  class CertificateInfo < Data.define(:subject, :issuer, :not_before, :not_after, :serial_number)
  end

  # Server-reported certificate status for a company, augmented with
  # client-side expiry computations (+days_until_expiration+, +expiring_soon+).
  class CertificateStatus < Data.define(
    :has_certificate, :expires_on, :valid, :days_until_expiration, :expiring_soon, :details
  )
  end

  # Local-only validation and inspection of A1 digital certificates (PKCS#12,
  # +.pfx+/+.p12+). Uses only the +openssl+ stdlib — no network access, no new
  # runtime dependency.
  #
  # The PKCS#12 bytes and password are handled in-memory only and never logged,
  # persisted, or echoed into exception messages.
  module CertificateValidator
    # Default window (in days) within which a certificate is "expiring soon".
    DEFAULT_THRESHOLD_DAYS = 30

    # Number of seconds in a day, for day-delta math.
    SECONDS_PER_DAY = 86_400

    module_function

    # @param filename [String, nil] a certificate filename.
    # @return [Boolean] +true+ for +.pfx+/+.p12+ (case-insensitive).
    def supported_format?(filename)
      ext = filename.to_s.downcase.split(".").last
      %w[pfx p12].include?(ext)
    end

    # Parse PKCS#12 bytes with the given password and extract certificate
    # metadata.
    #
    # @param der_bytes [String] the raw +.pfx+/+.p12+ bytes.
    # @param password [String] the certificate password.
    # @return [Nfe::CertificateInfo]
    # @raise [Nfe::InvalidRequestError] on a wrong password or malformed DER.
    #   The message never includes the password or the raw bytes.
    def validate(der_bytes, password)
      pkcs12 = OpenSSL::PKCS12.new(der_bytes, password)
      cert = pkcs12.certificate

      CertificateInfo.new(
        subject: cert.subject.to_s,
        issuer: cert.issuer.to_s,
        not_before: cert.not_before,
        not_after: cert.not_after,
        serial_number: cert.serial.to_s
      )
    rescue OpenSSL::OpenSSLError, ArgumentError, TypeError
      raise Nfe::InvalidRequestError, "Certificado ou senha inválidos"
    end

    # Whole days from now until +not_after+ (negative once expired).
    #
    # @param not_after [Time, String] the expiry instant.
    # @return [Integer]
    def days_until_expiration(not_after)
      expiry = coerce_time(not_after)
      ((expiry - Time.now) / SECONDS_PER_DAY).floor
    end

    # @param not_after [Time, String] the expiry instant.
    # @param threshold_days [Integer] the "soon" window (default 30).
    # @return [Boolean] +true+ when expiry is within +[0, threshold_days)+.
    def expiring_soon?(not_after, threshold_days = DEFAULT_THRESHOLD_DAYS)
      days = days_until_expiration(not_after)
      days >= 0 && days < threshold_days
    end

    # @api private
    def coerce_time(value)
      value.is_a?(Time) ? value : Time.parse(value.to_s)
    end
  end
end
