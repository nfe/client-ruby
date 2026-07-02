# frozen_string_literal: true

module Nfe
  module Http
    # Builds the +User-Agent+ string sent with every outgoing request.
    #
    # The format is
    # <tt>NFE.io Ruby Client v<sdk-version> ruby/<ruby-version> (<platform>)</tt>,
    # optionally followed by a caller-supplied suffix (e.g. the host
    # application's name configured via +Nfe::Configuration#user_agent_suffix+).
    #
    # Injection of the resulting header onto a request is performed by the
    # +Client+/+AbstractResource+ layer (see the +add-client-core+ change); the
    # transport itself only transmits whatever +User-Agent+ the +Request+ carries.
    module UserAgent
      module_function

      # Returns the User-Agent string. When +suffix+ is a non-empty string it is
      # appended after a single space.
      def build(suffix = nil)
        base = "NFE.io Ruby Client v#{Nfe::VERSION} ruby/#{RUBY_VERSION} (#{RUBY_PLATFORM})"
        return base if suffix.nil? || suffix.to_s.empty?

        "#{base} #{suffix}"
      end
    end
  end
end
