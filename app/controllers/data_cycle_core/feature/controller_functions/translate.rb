# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module Translate
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.prepend do
            post '/things/translate_text', action: :translate_text, controller: 'things', as: 'translate_text_thing' unless has_named_route?(:translate_text_thing)
          end
          Rails.application.reload_routes!
        end

        def translate_text
          # binding.pry
          render(plain: { error: I18n.t(:no_data, scope: [:validation, :warnings], data: 'Übersetzung', locale: DataCycleCore.ui_language) }.to_json, content_type: 'application/json') && return if text_params.blank? || text_params.values.all?(&:blank?)

          translated_text = DataCycleCore::Feature::Translate.translate_text(text_params.to_h, locale_params[:locale])
          # binding.pry

          render(plain: { error: translated_text.error }.to_json, content_type: 'application/json') && return if translated_text.try(:error).present?

          render plain: translated_text.compact.to_json, content_type: 'application/json'
        end

        private

        def text_params
          params.permit(:text)
        end

        def locale_params
          params.permit(:locale)
        end
      end
    end
  end
end
