# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module NamedVersion
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.prepend do
            patch '/things/remove_version_name', action: :remove_version_name, controller: 'things', as: 'remove_version_name' unless has_named_route?(:remove_version_name)
          end
          Rails.application.reload_routes!
        end

        def remove_version_name
          version_name_params[:class_name].safe_constantize.find(version_name_params[:id]).update_column(:version_name, nil)

          @success_message = I18n.t(:version_name_removed, scope: [:feature, :named_version], locale: DataCycleCore.ui_language)

          respond_to do |format|
            format.js
            format.html { redirect_back(fallback_location: root_path, notice: @success_message) }
          end
        end

        private

        def version_name_params
          params.permit(:class_name, :id)
        end
      end
    end
  end
end
