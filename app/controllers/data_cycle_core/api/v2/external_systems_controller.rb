# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class ExternalSystemsController < Api::V2::ApiBaseController
        def show
          external_system = DataCycleCore::ExternalSystem.find(permitted_params.dig(:id))
          raise unless external_system.name == 'OutdoorActive'

          # TODO: check if external_system_data exits, otherwise raise

          ids = permitted_params.dig(:ids).split(',')
          content = DataCycleCore::Thing.where(id: ids)

          xml_content = DataCycleCore::Export::OutdoorActive::Transformations.to_xml(external_system, content)

          content.each do |item|
            reset_external_data(item, external_system)
          end

          render xml: xml_content
        end

        def reset_external_data(content, external_system)
          external_data = content.external_system_data(external_system)
          return if external_data.blank?
          external_data.delete('job_id')
          content.add_external_system_data(external_system, external_data)
        end

        def permitted_parameter_keys
          super + [:id, :ids]
        end
      end
    end
  end
end
