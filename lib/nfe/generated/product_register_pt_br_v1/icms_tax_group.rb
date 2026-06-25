# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/product-register-pt-br-v1.yaml
# Hash: sha256:beba0a3fb4dc1bc157a5a4a28e55768cea0e7390b491bdd4bedee2ee2297ca64

module Nfe
  module Generated
    module ProductRegisterPtBrV1
      IcmsTaxGroup = Data.define(:cst, :mod_bc, :mod_bcst, :mot_des_icms, :mot_des_icmsst, :p_cred_sn, :p_dif, :p_fcp, :p_fcpdif, :p_fcpst, :p_fcpstret, :p_icms, :p_icmsefet, :p_icmsst, :p_mvast, :p_red_bc, :p_red_bcefet, :p_red_bcst) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            cst: payload["cst"],
            mod_bc: payload["modBC"],
            mod_bcst: payload["modBCST"],
            mot_des_icms: payload["motDesICMS"],
            mot_des_icmsst: payload["motDesICMSST"],
            p_cred_sn: payload["pCredSN"],
            p_dif: payload["pDif"],
            p_fcp: payload["pFCP"],
            p_fcpdif: payload["pFCPDif"],
            p_fcpst: payload["pFCPST"],
            p_fcpstret: payload["pFCPSTRet"],
            p_icms: payload["pICMS"],
            p_icmsefet: payload["pICMSEfet"],
            p_icmsst: payload["pICMSST"],
            p_mvast: payload["pMVAST"],
            p_red_bc: payload["pRedBC"],
            p_red_bcefet: payload["pRedBCEfet"],
            p_red_bcst: payload["pRedBCST"],
          )
        end
      end
    end
  end
end
