# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module GeoKeyFigure
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.prepend do
            get '/things/:id/geo_key_figure', action: :geo_key_figure, controller: 'things', as: 'geo_key_figure_thing' unless has_named_route?(:geo_key_figure_thing)
          end
          Rails.application.reload_routes!
        end

        def geo_key_figure
          render(plain: { error: I18n.t(:no_data, scope: [:validation, :warnings], data: 'GeoKeyFigure', locale: helpers.active_ui_locale) }.to_json, content_type: 'application/json') && return if geo_key_figure_params[:id].blank? || geo_key_figure_params[:part_ids].blank?

          content = DataCycleCore::Thing.find(geo_key_figure_params[:id])
          new_value = content.get_key_figure(geo_key_figure_params[:part_ids], geo_key_figure_params[:key])

          render plain: { newValue: new_value }.to_json, content_type: 'application/json'
        end

        private

        def geo_key_figure_params
          params.permit(:id, :key, part_ids: [])
        end
      end
    end
  end
end
