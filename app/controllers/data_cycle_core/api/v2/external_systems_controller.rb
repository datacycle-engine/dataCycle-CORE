# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class ExternalSystemsController < Api::V2::ApiBaseController
        after_action :check_job_status, only: [:show]

        def show
          external_system = DataCycleCore::ExternalSystem.find(permitted_params.dig(:id))
          raise unless external_system.name == 'OutdoorActive'

          ids = permitted_params.dig(:ids).split(',')
          content = DataCycleCore::Thing.where(id: ids)

          deleted_content_ids = (ids - content.map(&:id))

          init_logging do |logger|
            logger.info("DataCycleCore::Api::V2.show for external_system: #{external_system.try(:name)}", nil)
            logger.info('controller show --> delete_items', deleted_content_ids.join(', ')) if deleted_content_ids.size.positive?
            logger.info('controller show --> update_items', content.map(&:id).join(', ')) if content.map(&:id).size.positive?
          end

          xml_content = DataCycleCore::Export::OutdoorActive::Transformations.to_xml(external_system, content, deleted_content_ids)

          render xml: xml_content
        end

        def permitted_parameter_keys
          super + [:id, :ids]
        end

        private

        def check_job_status
          external_system = DataCycleCore::ExternalSystem.find(permitted_params.dig(:id))
          ids = permitted_params.dig(:ids).split(',')
          items = DataCycleCore::Thing.where(id: ids)

          init_logging do |logger|
            logger.info("DataCycleCore::Api::V2.check_job_status for external_system: #{external_system.try(:name)}", nil)
            logger.info("--> #{ids}")
          end

          items.each do |item|
            utility_object = DataCycleCore::Export::RefreshObject.new(external_system: external_system)
            job_id = item.external_system_data(external_system)&.dig('job_id')

            init_logging do |logger|
              logger.info("inspecting item id:#{item.id} --> job_id:#{job_id}", nil)
            end

            next if job_id.blank?
            DataCycleCore::Export::OutdoorActive::JobStatus.process(utility_object: utility_object, options: { job_id: job_id })
          end
        end

        def init_logging
          logging = DataCycleCore::Generic::Logger::LogFile.new(:export)
          yield(logging)
        ensure
          logging.close if logging.respond_to?(:close)
        end
      end
    end
  end
end
