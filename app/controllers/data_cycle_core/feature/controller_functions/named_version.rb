# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module NamedVersion
        extend ActiveSupport::Concern

        def remove_version_name
          @content = version_name_params[:class_name].safe_constantize.find(version_name_params[:id])
          version_name_params[:class_name].safe_constantize.find(version_name_params[:id])
          authorize!(:remove_version_name, @content)

          @content.update_column(:version_name, nil)

          @success_message = I18n.t(:version_name_removed, scope: [:feature, :named_version], locale: helpers.active_ui_locale)

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
