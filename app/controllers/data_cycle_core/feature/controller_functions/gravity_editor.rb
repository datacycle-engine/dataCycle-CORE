# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module GravityEditor
        extend ActiveSupport::Concern

        def update_gravity
          content = DataCycleCore::Thing.find(params[:id])
          authorize! :edit, content
          authorize! :update, DataCycleCore::DataAttribute.new(DataCycleCore::Feature::GravityEditor.attribute_keys.first, content.properties_for(DataCycleCore::Feature::GravityEditor.attribute_keys.first), {}, content, :update)
          if gravity_editor_params.key?(:gravity)
            content.set_data_hash(data_hash: { 'gravity' => Array.wrap(gravity_editor_params[:gravity].presence) }, current_user:)
          else
            render json: { error: I18n.t('controllers.error.missing_parameter', locale: helpers.active_ui_locale) }, status: :bad_request
          end
        end

        private

        def gravity_editor_params
          params.permit(:gravity)
        end
      end
    end
  end
end
