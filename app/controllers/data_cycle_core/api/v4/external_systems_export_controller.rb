# frozen_string_literal: true

module DataCycleCore
  module Api
    module V4
      class ExternalSystemsExportController < ApiBaseController
        def show
          external_system = DataCycleCore::ExternalSystem.find_by(identifier: permitted_params[:external_system_id]) ||
            DataCycleCore::ExternalSystem.find(permitted_params[:external_system_id])

          content = DataCycleCore::Thing.find(permitted_params[:id])

          transformations = external_system.config.dig('export_config', 'transformations').constantize

          render transformations.format => transformations.render(content, external_system)
        end

        def permitted_params
          @permitted_params ||= params.permit(:external_system_id, :id)
        end
      end
    end
  end
end
