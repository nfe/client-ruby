# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/calculo-impostos-v1.yaml
# Hash: sha256:39f6c3a1112ff3c98d842e172be5007eaa4d0c5f63d300ad263b96c9299ece99

module Nfe
  module Generated
    module CalculoImpostosV1
      Icms = Data.define(:c_benef_rbc, :csosn, :cst, :ind_deduz_deson, :mod_bc, :mod_bcst, :mot_des_icms, :mot_des_icmsst, :orig, :p_cred_sn, :p_dif, :p_fcp, :p_fcpdif, :p_fcpst, :p_fcpstret, :p_icms, :p_icmsefet, :p_icmsst, :p_mvast, :p_red_bc, :p_red_bcefet, :p_red_bcst, :p_st, :v_bc, :v_bcefet, :v_bcfcp, :v_bcfcpst, :v_bcfcpstret, :v_bcst, :v_bcstret, :v_cred_icmssn, :v_fcp, :v_fcpdif, :v_fcpefet, :v_fcpst, :v_fcpstret, :v_icms, :v_icmsdeson, :v_icmsdif, :v_icmsefet, :v_icmsop, :v_icmsst, :v_icmsstdeson, :v_icmsstret, :v_icmssubstituto) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            c_benef_rbc: payload["cBenefRBC"],
            csosn: payload["csosn"],
            cst: payload["cst"],
            ind_deduz_deson: payload["indDeduzDeson"],
            mod_bc: payload["modBC"],
            mod_bcst: payload["modBCST"],
            mot_des_icms: payload["motDesICMS"],
            mot_des_icmsst: payload["motDesICMSST"],
            orig: payload["orig"],
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
            p_st: payload["pST"],
            v_bc: payload["vBC"],
            v_bcefet: payload["vBCEfet"],
            v_bcfcp: payload["vBCFCP"],
            v_bcfcpst: payload["vBCFCPST"],
            v_bcfcpstret: payload["vBCFCPSTRet"],
            v_bcst: payload["vBCST"],
            v_bcstret: payload["vBCSTRet"],
            v_cred_icmssn: payload["vCredICMSSN"],
            v_fcp: payload["vFCP"],
            v_fcpdif: payload["vFCPDif"],
            v_fcpefet: payload["vFCPEfet"],
            v_fcpst: payload["vFCPST"],
            v_fcpstret: payload["vFCPSTRet"],
            v_icms: payload["vICMS"],
            v_icmsdeson: payload["vICMSDeson"],
            v_icmsdif: payload["vICMSDif"],
            v_icmsefet: payload["vICMSEfet"],
            v_icmsop: payload["vICMSOp"],
            v_icmsst: payload["vICMSST"],
            v_icmsstdeson: payload["vICMSSTDeson"],
            v_icmsstret: payload["vICMSSTRet"],
            v_icmssubstituto: payload["vICMSSubstituto"],
          )
        end
      end
    end
  end
end
