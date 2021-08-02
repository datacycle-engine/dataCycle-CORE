# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module AutoTagging
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.prepend do
            get '/things/:id/auto_tagging', action: :auto_tagging, controller: 'things', as: 'auto_tagging_thing' unless has_named_route?(:auto_tagging_thing)
          end
          Rails.application.reload_routes!
        end

        def auto_tagging
          render(plain: { error: I18n.t(:no_data, scope: [:validation, :errors], data: 'AutoTagging', locale: helpers.active_ui_locale) }.to_json, content_type: 'application/json') && return if tagging_params[:id].blank?

          thing = DataCycleCore::Thing.find(tagging_params[:id])
          @tag_ids = thing.auto_tag
          @key = tagging_params[:key]

          respond_to :js
        end

        private

        def tagging_params
          params.permit(:id, :key)
        end
      end
    end
  end
end
