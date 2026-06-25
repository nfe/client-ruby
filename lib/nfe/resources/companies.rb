# frozen_string_literal: true

require "json"
require "time"
require "nfe/resources/abstract_resource"
require "nfe/resources/dto/company"
require "nfe/certificate"

module Nfe
  module Resources
    # Companies resource for the +:main+ host family
    # (+https://api.nfe.io/v1/...+). Exposes the company CRUD plus the digital
    # certificate lifecycle (upload/replace/validate/status) and convenience
    # finders. The NFE.io API wraps company responses in a
    # +{"companies" => <object|array>}+ envelope, transparently unwrapped here
    # before hydrating {Nfe::Company}.
    #
    # @example
    #   company = client.companies.create(name: "Acme", federalTaxNumber: "12345678000199")
    #   client.companies.retrieve(company.id)
    class Companies < AbstractResource
      ENVELOPE = "companies"

      protected

      def api_family
        :main
      end

      public

      # Create a company. Validates +federalTaxNumber+ format (11/14 digits,
      # never coerced to Integer) and e-mail format when present.
      #
      # @param data [Hash] company attributes (camelCase keys per the API).
      # @return [Nfe::Company]
      def create(data)
        validate_company_data(data)
        response = post("/companies", body: json_body(data), headers: json_headers)
        hydrate(Nfe::Company, unwrap(parse_json(response.body), ENVELOPE))
      end

      # List one page of companies, converting the API's 1-based +page+ to a
      # 0-based +page_index+.
      #
      # @param page_index [Integer] 0-based page index.
      # @param page_count [Integer] page size.
      # @return [Nfe::ListResponse]
      def list(page_index: 0, page_count: 100)
        response = get("/companies", query: { pageIndex: page_index, pageCount: page_count })
        payload = parse_json(response.body) || {}
        items = (unwrap(payload, ENVELOPE) || []).map { |item| hydrate(Nfe::Company, item) }
        resolved_index = resolve_page_index(payload, page_index)
        Nfe::ListResponse.new(
          data: items,
          page: Nfe::ListPage.from_page(page_index: resolved_index, page_count: page_count)
        )
      end

      # Fetch every company by auto-paginating with +page_count: 100+ until a
      # short page is returned. Convenience helper; not optimized for large
      # accounts.
      #
      # @return [Array<Nfe::Company>]
      def list_all
        list_each.to_a
      end

      # Stream companies lazily, one per +yield+, fetching pages on demand.
      # Convenience helper; not optimized for large accounts.
      #
      # @return [Enumerator<Nfe::Company>]
      def list_each
        Enumerator.new do |yielder|
          page_index = 0
          loop do
            page = list(page_index: page_index, page_count: 100)
            page.data.each { |company| yielder << company }
            break if page.data.length < 100

            page_index += 1
          end
        end
      end

      # Retrieve a company by id.
      #
      # @param company_id [String]
      # @return [Nfe::Company]
      # @raise [Nfe::NotFoundError] when the API responds 404.
      def retrieve(company_id)
        id = Nfe::IdValidator.company_id(company_id)
        response = get("/companies/#{id}")
        hydrate(Nfe::Company, unwrap(parse_json(response.body), ENVELOPE))
      end

      # Update a company.
      #
      # @param company_id [String]
      # @param data [Hash]
      # @return [Nfe::Company]
      def update(company_id, data)
        id = Nfe::IdValidator.company_id(company_id)
        validate_company_data(data)
        response = put("/companies/#{id}", body: json_body(data), headers: json_headers)
        hydrate(Nfe::Company, unwrap(parse_json(response.body), ENVELOPE))
      end

      # Delete a company. Named +remove+ to avoid clashing with +delete+
      # semantics (parity with the Node/PHP SDKs).
      #
      # @param company_id [String]
      # @return [Hash] +{ deleted: true, id: company_id }+.
      def remove(company_id)
        id = Nfe::IdValidator.company_id(company_id)
        delete("/companies/#{id}")
        { deleted: true, id: id }
      end

      # Find a company by federal tax number (CNPJ/CPF). Convenience helper built
      # on {#list_all} plus client-side filtering; not optimized for large
      # accounts.
      #
      # @param tax_number [String, Integer]
      # @return [Nfe::Company, nil]
      def find_by_tax_number(tax_number)
        normalized = normalize_tax_number(tax_number)
        list_each.find { |company| normalize_tax_number(company.federal_tax_number) == normalized }
      end

      # Find companies whose name contains +name+ (case-insensitive). Convenience
      # helper built on {#list_all}; not optimized for large accounts.
      #
      # @param name [String]
      # @return [Array<Nfe::Company>]
      def find_by_name(name)
        term = name.to_s.strip
        raise Nfe::InvalidRequestError, "nome de busca (name) não pode ser vazio" if term.empty?

        term = term.downcase
        list_all.select { |company| company.name.to_s.downcase.include?(term) }
      end

      # Validate a PKCS#12 certificate locally (no HTTP) and extract its
      # metadata. The password and bytes are handled in-memory only.
      #
      # @param file [String] a file path or the raw .pfx/.p12 bytes.
      # @param password [String]
      # @return [Nfe::CertificateInfo]
      # @raise [Nfe::InvalidRequestError] on wrong password or malformed DER.
      def validate_certificate(file:, password:)
        Nfe::CertificateValidator.validate(read_certificate_bytes(file), password)
      end

      # Upload a digital certificate, pre-validating it locally (fail-fast)
      # before POSTing a +multipart/form-data+ body to
      # +/companies/{id}/certificate+ with the +file+ and +password+ fields.
      #
      # @param company_id [String]
      # @param file [String] file path or raw bytes.
      # @param password [String]
      # @param filename [String, nil] used for the extension check and part name.
      # @return [Hash] +{ uploaded: bool, message: String? }+.
      def upload_certificate(company_id, file:, password:, filename: nil)
        id = Nfe::IdValidator.company_id(company_id)
        if filename && !Nfe::CertificateValidator.supported_format?(filename)
          raise Nfe::InvalidRequestError,
                "formato de certificado não suportado: apenas .pfx e .p12 são aceitos"
        end

        bytes = read_certificate_bytes(file)
        Nfe::CertificateValidator.validate(bytes, password) # fail-fast, raises on invalid

        response = upload_multipart(
          "/companies/#{id}/certificate",
          "file" => { filename: filename || "certificate.pfx",
                      content: bytes, content_type: "application/x-pkcs12" },
          "password" => password
        )
        payload = parse_json(response.body) || {}
        { uploaded: true, message: payload["message"] }
      end

      # Replace an existing certificate. Alias of {#upload_certificate} — the API
      # handles replacement.
      #
      # @see #upload_certificate
      def replace_certificate(company_id, file:, password:, filename: nil)
        upload_certificate(company_id, file: file, password: password, filename: filename)
      end

      # Fetch certificate status, computing +days_until_expiration+ and
      # +expiring_soon+ client-side from +expires_on+ when present.
      #
      # @param company_id [String]
      # @return [Nfe::CertificateStatus]
      def get_certificate_status(company_id)
        id = Nfe::IdValidator.company_id(company_id)
        response = get("/companies/#{id}/certificate")
        details = parse_json(response.body) || {}
        build_certificate_status(details)
      end

      # Return an expiry warning when the certificate expires within
      # +threshold_days+, otherwise +nil+.
      #
      # @param company_id [String]
      # @param threshold_days [Integer]
      # @return [Hash, nil] +{ expiring: true, days_remaining:, expires_on: }+.
      def check_certificate_expiration(company_id, threshold_days: 30)
        status = get_certificate_status(company_id)
        return nil unless status.has_certificate && status.expires_on

        days = status.days_until_expiration
        return nil if days.nil?

        return unless days >= 0 && days < threshold_days

        { expiring: true, days_remaining: days, expires_on: status.expires_on }
      end

      # List companies that have a valid certificate. Convenience helper:
      # {#list_all} + one +get_certificate_status+ per company (companies whose
      # status lookup fails are skipped).
      #
      # @return [Array<Nfe::Company>]
      def get_companies_with_certificates
        list_all.select do |company|
          status = certificate_status_or_nil(company.id.to_s)
          status&.has_certificate && status.valid
        end
      end

      # List companies whose certificate expires within +threshold_days+.
      # Convenience helper; companies whose status lookup fails are skipped.
      #
      # @param threshold_days [Integer]
      # @return [Array<Nfe::Company>]
      def get_companies_with_expiring_certificates(threshold_days: 30)
        list_all.select do |company|
          expiring_or_nil(company.id.to_s, threshold_days)
        end
      end

      private

      def json_headers
        { "Content-Type" => "application/json" }
      end

      def json_body(data)
        JSON.generate(data)
      end

      # API uses 1-based +page+; convert to 0-based, falling back to the
      # requested index when the API omits it.
      def resolve_page_index(payload, requested_index)
        api_page = payload["page"] || payload[:page]
        return requested_index if api_page.nil?

        api_page - 1
      end

      # Validate +federalTaxNumber+ format/length and e-mail without coercing to
      # Integer or running check-digit rules (design D12). Tolerant of both
      # camelCase and snake_case keys.
      def validate_company_data(data)
        tax = data[:federalTaxNumber] || data["federalTaxNumber"] ||
              data[:federal_tax_number] || data["federal_tax_number"]
        unless tax.nil?
          digits = normalize_tax_number(tax)
          unless [11, 14].include?(digits.length)
            raise Nfe::InvalidRequestError,
                  "federalTaxNumber deve conter 11 dígitos (CPF) ou 14 (CNPJ)"
          end
        end

        email = data[:email] || data["email"]
        return if email.nil?
        return if /\A[^\s@]+@[^\s@]+\.[^\s@]+\z/.match?(email.to_s)

        raise Nfe::InvalidRequestError, "e-mail (email) com formato inválido"
      end

      def normalize_tax_number(value)
        value.to_s.gsub(/[^0-9A-Za-z]/, "")
      end

      # Read certificate bytes from a file path or accept raw bytes verbatim.
      # Raw PKCS#12 (DER) bytes contain NUL bytes, which would make +File.file?+
      # raise "path name contains null byte" — so a value with a NUL byte is
      # always treated as content, and the path check runs only on NUL-free
      # strings (which cannot trigger that error).
      def read_certificate_bytes(file)
        bytes = file.to_s.dup.force_encoding(Encoding::ASCII_8BIT)
        return File.binread(file) if file.is_a?(String) && !bytes.include?("\x00".b) && File.file?(file)

        bytes
      end

      def build_certificate_status(details)
        has_certificate = details["hasCertificate"] || details["has_certificate"] || false
        expires_on = details["expiresOn"] || details["expires_on"]
        valid = details.key?("isValid") ? details["isValid"] : details["valid"]

        days = nil
        expiring = nil
        if has_certificate && expires_on
          not_after = Time.parse(expires_on.to_s)
          days = Nfe::CertificateValidator.days_until_expiration(not_after)
          expiring = Nfe::CertificateValidator.expiring_soon?(not_after)
        end

        Nfe::CertificateStatus.new(
          has_certificate: has_certificate, expires_on: expires_on, valid: valid,
          days_until_expiration: days, expiring_soon: expiring, details: details
        )
      end

      def certificate_status_or_nil(company_id)
        get_certificate_status(company_id)
      rescue Nfe::Error
        nil
      end

      def expiring_or_nil(company_id, threshold_days)
        check_certificate_expiration(company_id, threshold_days: threshold_days)
      rescue Nfe::Error
        nil
      end
    end
  end
end
