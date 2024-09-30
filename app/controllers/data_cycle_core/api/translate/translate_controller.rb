# frozen_string_literal: true

module DataCycleCore
  module Api
    module Translate
      class TranslateController < DataCycleCore::Api::V4::ApiBaseController
        TRANSLATE_PARAMS = [:text, :source_locale, :target_locale].freeze
        VALIDATE_PARAMS_CONTRACT = DataCycleCore::MasterData::Contracts::ApiTranslationContract

        def translate_text
          authorize! :api_translate_text, DataCycleCore::Feature::Translate

          translate_params = permitted_params.slice(*TRANSLATE_PARAMS)

          errors = check_params translate_params

          render json: { error: errors }, status: :bad_request and return if errors.present?

          translated_text = DataCycleCore::Feature::Translate.translate_text(translate_params.to_h)

          render json: { error: translated_text.error } and return if translated_text.try(:error).present?

          render json: translated_text.compact
        rescue DataCycleCore::Generic::Common::Error::EndpointError => e
          error_message = 'An error occurred while translating the text'
          error_message += " (#{e.response.try(:status)})" if e.response.try(:status)
          render json: { error: error_message }, status: :internal_server_error
        end

        private

        def permitted_parameter_keys
          super + TRANSLATE_PARAMS
        end

        def check_params(translate_params)
          errors = []
          errors << 'Source and target locale should be different' if translate_params[:source_locale] == translate_params[:target_locale] && [translate_params[:source_locale], translate_params[:target_locale]].all?(&:present?)
          errors << 'Source locale not found in available locales' if translate_params[:source_locale].present? && I18n.available_locales.exclude?(translate_params[:source_locale].to_sym) && DataCycleCore::Feature::Translate.allowed_languages.exclude?(translate_params[:source_locale])
          errors << 'Target locale not found in available locales' if translate_params[:target_locale].present? && I18n.available_locales.exclude?(translate_params[:target_locale].to_sym) && DataCycleCore::Feature::Translate.allowed_languages.exclude?(translate_params[:target_locale])
          errors
        end
      end
    end
  end
end
