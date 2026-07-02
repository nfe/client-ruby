# frozen_string_literal: true

module Nfe
  module Http
    # Immutable retry policy describing exponential backoff with symmetric
    # jitter. Consumed by {RetryingTransport} to decide how long to wait between
    # attempts.
    #
    # +max_retries+ is the number of *retries* after the initial attempt, so a
    # policy with +max_retries: 3+ makes at most four HTTP attempts.
    #
    # Use the {.default} factory for the recommended settings, or {.none} to
    # disable retries entirely (exactly one HTTP attempt).
    class RetryPolicy < Data.define(:max_retries, :base_delay, :max_delay, :jitter)
      # Recommended defaults: 3 retries, 1s base, 30s cap, +/-30% jitter.
      def self.default
        new(max_retries: 3, base_delay: 1.0, max_delay: 30.0, jitter: 0.3)
      end

      # No retries: exactly one HTTP attempt, zero delay.
      def self.none
        new(max_retries: 0, base_delay: 0.0, max_delay: 0.0, jitter: 0.0)
      end

      # Delay in seconds before the given (1-based) retry +attempt+.
      #
      # Computes +min(max_delay, base_delay * 2**(attempt - 1))+ then applies
      # symmetric jitter, with the final value capped at +max_delay+.
      #
      # @param attempt [Integer] 1-based retry index.
      # @return [Float]
      def delay_for(attempt)
        base = [base_delay * (2**(attempt - 1)), max_delay].min
        jittered = base * (1 - jitter + (2 * jitter * rand))
        [jittered, max_delay].min
      end
    end
  end
end
