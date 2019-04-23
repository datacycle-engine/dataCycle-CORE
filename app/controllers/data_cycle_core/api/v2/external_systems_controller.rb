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

          xml_content = DataCycleCore::Export::OutdoorActive::Transformations.to_xml(external_system, content)

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

          items.each do |item|
            utility_object = DataCycleCore::Export::RefreshObject.new(external_system: external_system)
            job_id = item.external_system_data(external_system)&.dig('job_id')
            next if job_id.blank?
            DataCycleCore::Export::OutdoorActive::JobStatus.process(utility_object: utility_object, options: { job_id: job_id })
          end
        end
      end
    end
  end
end
