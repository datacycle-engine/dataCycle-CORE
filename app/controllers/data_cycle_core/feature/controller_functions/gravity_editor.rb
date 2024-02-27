# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module GravityEditor
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.prepend do
            authenticate do
              patch '/things/:id/update_gravity', action: :update_gravity, controller: 'things', as: 'update_gravity_thing' unless has_named_route?(:update_gravity_thing)
            end
          end
          Rails.application.reload_routes!
        end

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
