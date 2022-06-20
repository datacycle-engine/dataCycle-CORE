# frozen_string_literal: true

module DataCycleCore
  module Export
    module OutdoorActive
      module JobStatus
        include Functions

        def self.process(utility_object:, options: {})
          items = DataCycleCore::Thing
            .includes(:external_system_syncs)
            .where(external_system_syncs: { external_system_id: utility_object.external_system.id, sync_type: 'export' })

          if options.dig(:job_id).present?
            items = items.where("external_system_syncs.data ->> 'job_id' = ?", options[:job_id])
          else
            items = items.where("external_system_syncs.data ->> 'job_id' IS NOT NULL")
          end

          init_logging do |logger|
            logger.info("DataCycleCore::Export::OutdoorActive::JobStatus#process: items(#{items.size}) -> #{items.pluck(:id)} | job_id=#{options.dig(:job_id)} |", nil)
          end

          items.each do |data|
            Functions.update_job_status(utility_object: utility_object, data: data)
          end
        end

        def self.init_logging
          logging = DataCycleCore::Generic::Logger::LogFile.new(:export)
          yield(logging)
        ensure
          logging.close if logging.respond_to?(:close)
        end
      end
    end
  end
end
