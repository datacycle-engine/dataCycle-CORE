# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module GipKeyFigure
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.prepend do
            get '/things/:id/gip_key_figure', action: :gip_key_figure, controller: 'things', as: 'gip_key_figure_thing' unless has_named_route?(:gip_key_figure_thing)
          end
          Rails.application.reload_routes!
        end

        def gip_key_figure
          render(plain: { error: I18n.t(:no_data, scope: [:validation, :warnings], data: 'GipKeyFigure', locale: DataCycleCore.ui_language) }.to_json, content_type: 'application/json') && return if gip_key_figure_params[:id].blank? || gip_key_figure_params[:part_ids].blank?

          content = DataCycleCore::Thing.find(gip_key_figure_params[:id])
          new_value = content.get_key_figure(gip_key_figure_params[:part_ids], gip_key_figure_params[:key])

          render plain: { newValue: new_value }.to_json, content_type: 'application/json'
        end

        private

        def gip_key_figure_params
          params.permit(:id, :key, part_ids: [])
        end
      end
    end
  end
end
