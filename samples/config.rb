# frozen_string_literal: true

# Configuração compartilhada por todos os exemplos.
#
# Carregue com `require_relative "config"` no topo de cada exemplo. Ele:
#   * carrega a gem (preferindo a instalada; caindo para lib/ do repositório);
#   * lê as variáveis de ambiente (de um samples/.env opcional);
#   * monta um Nfe::Client global em $nfe;
#   * expõe $company_id;
#   * aborta com uma mensagem clara se NFE_API_KEY não estiver definida.
#
# Variáveis de ambiente (veja samples/.env.example):
#   NFE_API_KEY        — chave principal (obrigatória)
#   NFE_DATA_API_KEY   — chave de dados (opcional; cai para NFE_API_KEY)
#   NFE_COMPANY_ID     — id da empresa usada nos exemplos
#   NFE_WEBHOOK_SECRET — segredo do webhook (apenas webhook_verify.rb)

# Carrega um samples/.env simples (KEY=VALUE por linha), sem dependências
# externas. Variáveis já presentes no ambiente têm precedência.
env_path = File.join(__dir__, ".env")
if File.file?(env_path)
  File.foreach(env_path) do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")

    key, _, value = line.partition("=")
    key = key.strip
    next if key.empty?

    ENV[key] ||= value.strip
  end
end

# Prefere a gem instalada; cai para a lib/ do repositório quando rodando a
# partir do checkout (sem `gem install nfe-io`).
begin
  require "nfe"
rescue LoadError
  $LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
  require "nfe"
end

if ENV["NFE_API_KEY"].nil? || ENV["NFE_API_KEY"].strip.empty?
  abort <<~MSG
    NFE_API_KEY não definida.

    Copie samples/.env.example para samples/.env e preencha NFE_API_KEY,
    ou exporte a variável antes de rodar:

      export NFE_API_KEY="sua-chave"
      ruby samples/<exemplo>.rb
  MSG
end

# Cliente global compartilhado pelos exemplos.
$nfe = Nfe::Client.new(
  api_key: ENV["NFE_API_KEY"],
  data_api_key: ENV["NFE_DATA_API_KEY"]
)

# Id da empresa usada nos exemplos de emissão/CRUD (pode ser nil em exemplos
# que não precisam dela, como as consultas de CEP/CNPJ/CPF).
$company_id = ENV["NFE_COMPANY_ID"]
