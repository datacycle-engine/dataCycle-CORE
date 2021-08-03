# frozen_string_literal: true

module DataCycleCore
  module LocalizationService
    def self.localize_validation_errors(message_hash, locale)
      if message_hash[:error].is_a?(::Hash)
        message_hash[:error]&.transform_values! { |v| translate_and_substitute(v, locale) }
      else
        message_hash[:error] = translate_and_substitute(message_hash[:error], locale)
      end

      if message_hash[:warning].is_a?(::Hash)
        message_hash[:warning]&.transform_values! { |v| translate_and_substitute(v, locale) }
      else
        message_hash[:warning] = translate_and_substitute(message_hash[:warning], locale)
      end

      message_hash
    end

    def self.translate_and_substitute(translation_object, locale)
      return translation_object.map { |t| translate_and_substitute(t, locale) } if translation_object.is_a?(::Array)
      return translation_object unless translation_object.is_a?(::Hash)

      translation_object[:substitutions]&.transform_values! do |value|
        value.is_a?(::Hash) ? translate_and_substitute(value, locale) : value
      end

      if translation_object.key?(:path)
        I18n.t(
          translation_object[:path],
          (translation_object[:substitutions] || {}).merge(locale: locale)
        )
      elsif translation_object.key?(:localization_method)
        view_helpers.try(
          translation_object[:localization_method],
          translation_object[:localization_value],
          (translation_object[:substitutions] || {}).merge(locale: locale)
        )
      end
    end

    def self.view_helpers
      @view_helpers ||= ApplicationController.helpers
    end
  end
end
