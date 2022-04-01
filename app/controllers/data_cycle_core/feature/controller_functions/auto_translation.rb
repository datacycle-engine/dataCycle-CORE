# frozen_string_literal: true

module DataCycleCore
  module Feature
    module ControllerFunctions
      module AutoTranslation
        extend ActiveSupport::Concern

        included do
          DataCycleCore::Engine.routes.prepend do
            post '/things/:id/create_auto_translations', action: :create_auto_translations, controller: 'things', as: 'create_auto_translations_thing' unless has_named_route?(:create_auto_translations_thing)
            post '/things/:id/auto_translations', action: :auto_translations, controller: 'things', as: 'auto_translations_thing' unless has_named_route?(:auto_translations_thing)
          end
          Rails.application.reload_routes!
        end

        def auto_translations
          @content = DataCycleCore::Thing.find_by(id: params[:id])
          source_locale = param_source_locale || DataCycleCore::Feature::AutoTranslation.configuration['source_lang'] || I18n.locale
          render(plain: { error: I18n.t(:no_data, scope: [:validation, :warnings], data: 'Normalisierung', locale: helpers.active_ui_locale) }.to_json, content_type: 'application/json') && return if @content.blank?

          DataCycleCore::AutoTranslationJob.perform_later(params[:id], source_locale)
          redirect_back(fallback_location: root_path, notice: I18n.t(:auto_translation_submit, scope: [:common], locale: helpers.active_ui_locale))
        end

        private

        def param_source_locale
          params.permit(:source_locale)['source_locale']
        end
      end
    end
  end
end
