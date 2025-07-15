# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module FocusPointEditor
        extend ActiveSupport::Concern

        def update_focus_point
          content = DataCycleCore::Thing.find(params[:id])
          authorize_update_focus_point!(content)

          if focus_point_params.present?
            fparams = focus_point_params.to_h
            if fparams.values.all?(0.5) # reset focus point
              fparams.transform_values! { nil }
              message_key = 'reset_successfully'
            else
              message_key = 'updated_successfully'
            end
            if content.set_data_hash(data_hash: fparams, current_user:)
              render json: {
                message: I18n.t("feature.focus_point_editor.#{message_key}", locale: helpers.active_ui_locale)
              }
            else
              render json: {
                error: I18n.t('feature.focus_point_editor.update_error', locale: helpers.active_ui_locale)
              }
            end
          else
            render json: { error: I18n.t('controllers.error.missing_parameter', locale: helpers.active_ui_locale) }, status: :bad_request
          end
        end

        private

        def authorize_update_focus_point!(content)
          authorize! :update, content

          DataCycleCore::Feature::FocusPointEditor.attribute_keys.each do |attribute_key|
            authorize! :update, DataCycleCore::DataAttribute.new(attribute_key, content.properties_for(attribute_key), {}, content, :update)
          end
        end

        def focus_point_params
          params.require(:focus_point).permit(*DataCycleCore::Feature::FocusPointEditor.attribute_keys.map(&:to_sym))
        end
      end
    end
  end
end
