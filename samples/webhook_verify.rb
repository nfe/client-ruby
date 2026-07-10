# frozen_string_literal: true

# Verifica a assinatura de um webhook da NFE.io usando apenas a biblioteca
# padrão (sem frameworks). A NFE.io assina os BYTES EXATOS entregues
# (HMAC-SHA1, cabeçalho X-Hub-Signature) — leia o corpo bruto ANTES de
# parsear JSON e passe esses bytes.
#
# A assinatura prova autenticidade, NÃO atualidade (não há timestamp/nonce):
# handlers devem ser idempotentes e deduplicar pelo id do evento/nota.
#
# Pré-requisitos:
#   * NFE_WEBHOOK_SECRET — segredo configurado no destino do webhook
#
# Uso (demonstração com um corpo de exemplo assinado localmente):
#   ruby samples/webhook_verify.rb
#
# Em produção, dentro do seu handler HTTP (Rack/Sinatra/Rails):
#   raw = request.body.read                      # BYTES BRUTOS, antes do JSON
#   sig = request.get_header("HTTP_X_HUB_SIGNATURE")
#   if Nfe::Webhook.verify_signature(payload: raw, signature: sig, secret: ENV["NFE_WEBHOOK_SECRET"])
#     event = Nfe::Webhook.construct_event(payload: raw, signature: sig, secret: ENV["NFE_WEBHOOK_SECRET"])
#     # dedupe em event.id antes de processar event.type / event.data
#   end

require_relative "config"
require "openssl"

secret = ENV["NFE_WEBHOOK_SECRET"]
abort "Defina NFE_WEBHOOK_SECRET." if secret.nil? || secret.strip.empty?

# --- Demonstração: simula uma entrega assinando um corpo de exemplo. ---
# Em produção estes vêm da requisição HTTP, não são gerados aqui.
raw_payload = JSON.generate(
  {
    "id" => "evt_123",
    "action" => "service_invoice.issued_successfully",
    "payload" => { "id" => "inv_456", "flowStatus" => "Issued" }
  }
)
signature = "sha1=" + OpenSSL::HMAC.hexdigest("SHA1", secret, raw_payload)

# --- Verificação (nunca levanta exceção; retorna true/false). ---
valid = Nfe::Webhook.verify_signature(payload: raw_payload, signature: signature, secret: secret)
puts "Assinatura válida? #{valid}"

unless valid
  warn "Assinatura inválida — descarte a entrega."
  exit 1
end

# construct_event verifica de novo e, se válido, devolve um WebhookEvent.
event = Nfe::Webhook.construct_event(payload: raw_payload, signature: signature, secret: secret)
puts "Evento: type=#{event.type} id=#{event.id}"
puts "Dados: #{event.data.inspect}"
puts "Lembre: deduplique por event.id (#{event.id}) — o handler deve ser idempotente."
