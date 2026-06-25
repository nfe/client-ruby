# frozen_string_literal: true

module Nfe
  # Immutable value object for a consumer-invoice tax coupon (CFe-SAT)
  # returned by the +nfe.api.nfe.io+ query API
  # (+GET /v1/consumerinvoices/coupon/{accessKey}+).
  #
  # This is the QUERY (consulta) of an already-issued coupon by access key and
  # is DISTINCT from {Nfe::ConsumerInvoice} (the emission model handled by
  # {Nfe::Resources::ConsumerInvoices}) — different host and API version.
  #
  # All fields are optional; {from_api} maps the API camelCase keys onto the
  # snake_case members, hydrates the nested value objects, and is nil-tolerant
  # (+from_api(nil)+ returns +nil+). The nested objects ({Issuer}, {Buyer},
  # {Total}, {Delivery}, {AdditionalInformation}, {Item}, {Payment}) keep only a
  # pragmatic subset of the most common fields, mapped against the real CFe-SAT
  # +TaxCouponResource+ shape.
  class TaxCoupon < Data.define(
    :current_status,
    :number,
    :sat_serie,
    :software_version,
    :software_federal_tax_number,
    :access_key,
    :cashier,
    :issued_on,
    :created_on,
    :xml_version,
    :issuer,
    :buyer,
    :totals,
    :delivery,
    :additional_information,
    :items,
    :payment
  )
    # Issuer (emitente / +emit+) of the coupon.
    class Issuer < Data.define(:federal_tax_number, :name, :trade_name, :state_tax_number)
      def self.from_api(payload)
        return nil if payload.nil?

        new(
          federal_tax_number: payload["federalTaxNumber"]&.to_s,
          name: payload["name"],
          trade_name: payload["tradeName"],
          state_tax_number: payload["stateTaxNumber"]&.to_s
        )
      end
    end

    # Buyer (destinatário / consumidor / +dest+) of the coupon.
    class Buyer < Data.define(:federal_tax_number, :name)
      def self.from_api(payload)
        return nil if payload.nil?

        new(
          federal_tax_number: payload["federalTaxNumber"]&.to_s,
          name: payload["name"]
        )
      end
    end

    # Monetary totals of the coupon (+total+). +total_amount+ is the approximate
    # tax amount (vCFeLei12741) and +coupon_amount+ is the coupon grand total
    # (vCFe).
    class Total < Data.define(:total_amount, :coupon_amount)
      def self.from_api(payload)
        return nil if payload.nil?

        new(
          total_amount: payload["totalAmount"],
          coupon_amount: payload["couponAmount"]
        )
      end
    end

    # Delivery location (+entrega+) — the coupon delivery group only carries an
    # address.
    class Delivery < Data.define(:address)
      def self.from_api(payload)
        return nil if payload.nil?

        new(
          address: Address.from_api(payload["address"])
        )
      end
    end

    # Pragmatic subset of a CFe-SAT address (+enderEmit+ / +entrega.address+).
    class Address < Data.define(:street, :number, :district, :postal_code, :city, :state, :country)
      def self.from_api(payload)
        return nil if payload.nil?

        new(
          street: payload["street"],
          number: payload["number"]&.to_s,
          district: payload["district"],
          postal_code: payload["postalCode"]&.to_s,
          city: payload["city"],
          state: payload["state"],
          country: payload["country"]
        )
      end
    end

    # Free-form additional information block (+infAdic+).
    class AdditionalInformation < Data.define(:taxpayer)
      def self.from_api(payload)
        return nil if payload.nil?

        new(
          taxpayer: payload["taxpayer"]
        )
      end
    end

    # A single coupon line item (+det+ / +prod+).
    class Item < Data.define(:code, :description, :quantity, :unit_amount, :net_amount, :gross_amount, :cfop)
      def self.from_api(payload)
        return nil if payload.nil?

        new(
          code: payload["code"]&.to_s,
          description: payload["description"],
          quantity: payload["quantity"],
          unit_amount: payload["unitAmount"],
          net_amount: payload["netAmount"],
          gross_amount: payload["grossAmount"],
          cfop: payload["cfop"]
        )
      end
    end

    # A single payment-method detail (+pgto.MP+).
    class PaymentDetail < Data.define(:method, :amount, :card)
      def self.from_api(payload)
        return nil if payload.nil?

        new(
          method: payload["method"],
          amount: payload["amount"],
          card: payload["card"]
        )
      end
    end

    # Payment group for the coupon (+pgto+). +pay_back+ is the change/troco
    # (vTroco); +payment_details+ holds one entry per payment method.
    class Payment < Data.define(:pay_back, :payment_details)
      def self.from_api(payload)
        return nil if payload.nil?

        new(
          pay_back: payload["payBack"],
          payment_details: (payload["paymentDetails"] || []).map { |d| PaymentDetail.from_api(d) }
        )
      end
    end

    # Build a {Nfe::TaxCoupon} from an API payload.
    #
    # @param payload [Hash, nil] the parsed coupon object.
    # @return [Nfe::TaxCoupon, nil] +nil+ when +payload+ is +nil+.
    # rubocop:disable Metrics/AbcSize -- wide value-object mapping kept inline for Steep keyword-arg verification
    def self.from_api(payload)
      return nil if payload.nil?

      new(
        current_status: payload["currentStatus"],
        number: payload["number"],
        sat_serie: payload["satSerie"]&.to_s,
        software_version: payload["softwareVersion"],
        software_federal_tax_number: payload["softwareFederalTaxNumber"]&.to_s,
        access_key: payload["accessKey"]&.to_s,
        cashier: payload["cashier"],
        issued_on: payload["issuedOn"],
        created_on: payload["createdOn"],
        xml_version: payload["xmlVersion"],
        issuer: Issuer.from_api(payload["issuer"]),
        buyer: Buyer.from_api(payload["buyer"]),
        totals: Total.from_api(payload["totals"]),
        delivery: Delivery.from_api(payload["delivery"]),
        additional_information: AdditionalInformation.from_api(payload["additionalInformation"]),
        items: (payload["items"] || []).map { |i| Item.from_api(i) },
        payment: Payment.from_api(payload["payment"])
      )
    end
    # rubocop:enable Metrics/AbcSize
  end
end
