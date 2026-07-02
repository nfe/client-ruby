# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/consulta-nfe-distribuicao-v1.yaml
# Hash: sha256:c28db6c6fed93a58342537de8131850f266d0cdff71873a3bab126b3309e3ea7

module Nfe
  module Generated
    module ConsultaNfeDistribuicaoV1
      Links = Data.define(:pdf, :xml) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            pdf: payload["pdf"],
            xml: payload["xml"],
          )
        end
      end
    end
  end
end
