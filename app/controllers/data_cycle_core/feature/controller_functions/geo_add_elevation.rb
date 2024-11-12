# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module GeoAddElevation
        def geo_add_elevation
          render(plain: { error: I18n.t(:no_data, scope: [:validation, :warnings], data: 'GeoAddElevation', locale: helpers.active_ui_locale) }.to_json, content_type: 'application/json') && return if geo_add_elevation_params[:value].blank?

          new_value = DataCycleCore::Feature::GeoAddElevation.add_elevation_values(geo_add_elevation_params[:value].to_h)

          if new_value.try(:error).present?
            render(
              plain: {
                error: DataCycleCore::LocalizationService.translate_and_substitute(new_value.error, helpers.active_ui_locale)
              }.to_json,
              content_type: 'application/json'
            ) && return
          end

          render plain: { newValue: new_value }.to_json, content_type: 'application/json'
        end

        private

        def geo_add_elevation_params
          params.permit(value: {})
        end
      end
    end
  end
end
