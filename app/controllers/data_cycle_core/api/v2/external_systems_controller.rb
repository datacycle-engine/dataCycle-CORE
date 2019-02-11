# frozen_string_literal: true

module DataCycleCore
  module Api
    module V2
      class ExternalSystemsController < Api::V2::ApiBaseController
        def show
          external_system = DataCycleCore::ExternalSystem.find(permitted_params.dig(:external_system_id))
          raise unless external_system.name == 'OutdoorActive'

          # TODO: check if external_system_data exits, otherwise raise

          content = DataCycleCore::Thing.find(permitted_params.dig(:ids))

          xml_content = DataCycleCore::Export::OutdoorActive::Transformations.to_xml(external_system, content)

          external_data = content.external_system_data(external_system)
          if external_data.present?
            external_data.delete('job_id')
            content.add_external_system_data(external_system, external_data)
          end
          render xml: xml_content
        end

        def permitted_parameter_keys
          super + [:external_system_id, :ids]
        end
      end
    end
  end
end
