# frozen_string_literal: true

module Nfe
  # Result of an asynchronous (HTTP 202) invoice operation: the API accepted
  # the request and is processing it. The document is not yet materialized.
  #
  # +invoice_id+ is parsed from the +Location+ header's final path segment;
  # +location+ is the raw header value. Discriminate against {Nfe::Issued} with
  # +is_a?+/+case+ and poll {Nfe::FlowStatus.terminal?} until settled.
  class Pending < Data.define(:invoice_id, :location)
  end

  # Result of a synchronous (HTTP 201/200) invoice operation: the document was
  # materialized immediately. +resource+ is the hydrated DTO value object.
  class Issued < Data.define(:resource)
  end
end
