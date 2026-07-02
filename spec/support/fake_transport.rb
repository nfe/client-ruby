# frozen_string_literal: true

# In-memory transport double for tests. Responds to +call(request)+, dequeuing
# canned outcomes (an Nfe::Http::Response to return, or an exception instance /
# class to raise) and recording every received request for assertions.
#
# Usage:
#   fake = FakeTransport.new
#   fake.enqueue(Nfe::Http::Response.new(status: 503))
#   fake.enqueue(Nfe::Http::Response.new(status: 200))
#   fake.call(request) # => 503, then 200
#
# When the queue is exhausted, the last enqueued outcome is repeated, so a
# single enqueued 503 models a permanently failing endpoint.
class FakeTransport
  attr_reader :requests

  def initialize(outcomes = [])
    @outcomes = outcomes.dup
    @requests = []
  end

  # Enqueue a Response to return or an exception (class or instance) to raise.
  def enqueue(outcome)
    @outcomes << outcome
    self
  end

  def call(request)
    @requests << request
    outcome = @outcomes.length > 1 ? @outcomes.shift : @outcomes.first
    deliver(outcome)
  end

  # Number of times +call+ has been invoked.
  def call_count
    @requests.length
  end

  private

  def deliver(outcome)
    case outcome
    when Class
      raise outcome if outcome <= Exception

      outcome
    when Exception
      raise outcome
    else
      outcome
    end
  end
end
