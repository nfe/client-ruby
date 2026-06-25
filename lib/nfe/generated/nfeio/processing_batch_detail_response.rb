# frozen_string_literal: true
# AUTO-GENERATED — do not edit
# Source: openapi/nfeio.yaml
# Hash: sha256:813bda287538f8599c3565485eb523d1b1311b26b5be94ead62ba0b7a17f6af3

module Nfe
  module Generated
    module Nfeio
      ProcessingBatchDetailResponse = Data.define(:batch_processes, :created_at, :created_by, :id, :inputs, :metrics, :name, :resource_name, :stage, :status, :updated_at) do
        def self.from_api(payload)
          return nil if payload.nil?

          new(
            batch_processes: (payload["batchProcesses"] || []).map { |e| BatchProcessResponse.from_api(e) },
            created_at: payload["createdAt"],
            created_by: payload["createdBy"],
            id: payload["id"],
            inputs: InputsResponse.from_api(payload["inputs"]),
            metrics: ProcessingMetricsResponse.from_api(payload["metrics"]),
            name: payload["name"],
            resource_name: payload["resourceName"],
            stage: payload["stage"],
            status: payload["status"],
            updated_at: payload["updatedAt"],
          )
        end
      end
    end
  end
end
