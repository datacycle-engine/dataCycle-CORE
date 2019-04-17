# frozen_string_literal: true

module DataCycleCore
  module Export
    module OutdoorActive
      module JobStatus
        include Functions

        def self.process(utility_object:, options: {})
          items = DataCycleCore::Thing.joins(:external_systems)&.to_a&.select do |item|
            if options.dig(:job_id).present?
              item.external_system_data(utility_object.external_system).dig('job_id') == options.dig(:job_id)
            else
              item.external_system_data(utility_object.external_system).dig('job_id').present?
            end
          end
          items.each do |data|
            Functions.update_job_status(utility_object: utility_object, data: data)
          end
        end
      end
    end
  end
end
