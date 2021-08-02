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
          render(plain: { error: I18n.t(:no_data, scope: [:validation, :warnings], data: 'Übersetzung', locale: helpers.active_ui_locale) }.to_json, content_type: 'application/json') && return if translate_params.blank? || translate_params.values.all?(&:blank?)

          translated_text = DataCycleCore::Feature::Translate.translate_text(translate_params.to_h)

          render(plain: { error: translated_text.error }.to_json, content_type: 'application/json') && return if translated_text.try(:error).present?

          render plain: translated_text.compact.to_json, content_type: 'application/json'
        end

        private

        def translate_params
          params.permit(:text, :source_locale, :target_locale)
        end
      end
    end
  end
end
