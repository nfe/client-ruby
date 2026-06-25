# frozen_string_literal: true

module Nfe
  # Lifecycle status of an asynchronously-processed fiscal document.
  #
  # Terminal states stop polling; non-terminal states mean processing is still
  # in flight. The discriminated 202 Pending/Issued contract (modeled in the
  # resource changes) uses {FlowStatus.terminal?} to decide when a document is
  # settled.
  module FlowStatus
    # States in which processing has finished (success or failure).
    TERMINAL = %w[Issued IssueFailed Cancelled CancelFailed].freeze

    # States in which processing is still in progress.
    NON_TERMINAL = %w[
      PullFromCityHall
      WaitingCalculateTaxes
      WaitingDefineRpsNumber
      WaitingSend
      WaitingSendCancel
      WaitingReturn
      WaitingDownload
    ].freeze

    # Every known flow status.
    ALL = (TERMINAL + NON_TERMINAL).freeze

    module_function

    # Returns +true+ when +status+ is a terminal flow state.
    def terminal?(status)
      TERMINAL.include?(status.to_s)
    end
  end
end
