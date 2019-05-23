# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module AutoTagging
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.prepend do
            get '/things/auto_tagging', action: :auto_tagging, controller: 'things', as: 'auto_tagging_thing' unless has_named_route?(:auto_tagging_thing)
          end
          Rails.application.reload_routes!
        end

        def auto_tagging
          render(plain: { error: I18n.t(:no_data, scope: [:validation, :errors], data: 'AutoTagging', locale: DataCycleCore.ui_language) }.to_json, content_type: 'application/json') && return if tagging_params.blank? || tagging_params.values.all?(&:blank?)

          thing = DataCycleCore::Thing.find(tagging_params[:id])
          thing.auto_tag
          thing.save # maybe not necessary

          redirect_to thing_path(thing)
        end

        private

        def tagging_params
          params.permit(:id)
        end
      end
    end
  end
end
