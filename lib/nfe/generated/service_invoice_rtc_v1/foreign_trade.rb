# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/service-invoice-rtc-v1.yaml
# Hash: sha256:5c3b751b63e6a0adabb185b974e141f1b06127934fa0bf05fc505676024db32b

module Nfe
  module Generated
    module ServiceInvoiceRtcV1
      ForeignTrade = Data.define(:currency, :export_registration, :import_declaration, :mdic_delivery, :relation_ship, :service_amount_in_currency, :service_mode, :support_mechanism_provider, :support_mechanism_receiver, :temporary_goods) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            currency: payload["currency"],
            export_registration: payload["exportRegistration"],
            import_declaration: payload["importDeclaration"],
            mdic_delivery: payload["mdicDelivery"],
            relation_ship: payload["relationShip"],
            service_amount_in_currency: payload["serviceAmountInCurrency"],
            service_mode: payload["serviceMode"],
            support_mechanism_provider: payload["supportMechanismProvider"],
            support_mechanism_receiver: payload["supportMechanismReceiver"],
            temporary_goods: payload["temporaryGoods"],
          )
        end
      end
    end
  end
end
