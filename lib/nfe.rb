# frozen_string_literal: true

require "nfe/version"

# Error hierarchy + factory
require "nfe/errors"
require "nfe/error_factory"

# Value objects & validation helpers
require "nfe/results"
require "nfe/pagination"
require "nfe/request_options"
require "nfe/flow_status"
require "nfe/id_validator"

# Webhook signature verification + certificate handling
require "nfe/webhook_event"
require "nfe/webhook"
require "nfe/certificate"

# HTTP transport layer (zero-dependency, Net::HTTP-based)
require "nfe/http/request"
require "nfe/http/response"
require "nfe/http/transport"
require "nfe/http/redactor"
require "nfe/http/user_agent"
require "nfe/http/net_http"
require "nfe/http/retry_policy"
require "nfe/http/retrying_transport"

# Core DX layer (Client also requires Configuration, AbstractResource, and the 17 resource stubs)
require "nfe/configuration"
require "nfe/client"

# Official NFE.io SDK for Ruby.
#
# Zero runtime dependencies — Ruby stdlib only. Issue and manage Brazilian
# electronic fiscal documents (NFS-e, NF-e, NFC-e, CT-e) through a single
# Stripe-style client:
#
#   client = Nfe::Client.new(api_key: "your-api-key")
#   client.service_invoices # resources are lazy snake_case accessors
#
# See https://nfe.io for API documentation.
module Nfe
end
