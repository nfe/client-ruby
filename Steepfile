# frozen_string_literal: true

target :lib do
  signature "sig"
  check "lib"

  # Generated value objects (from the OpenAPI pipeline) are trusted by
  # construction and excluded from the strict check; refine as codegen matures.
  ignore "lib/nfe/generated"

  # Standard-library signatures used by the HTTP transport layer.
  library "json", "uri", "net-http", "zlib", "openssl", "stringio", "timeout", "socket"
end
