# frozen_string_literal: true

module DataCycleCore
  module LocalizationService
    def self.localize_validation_errors(message_hash, locale)
      return message_hash unless message_hash.is_a?(::Hash)

      localized_hash = message_hash.deep_dup
      localized_hash[:error] = translate_and_substitute(localized_hash[:error], locale)
      localized_hash[:warning] = translate_and_substitute(localized_hash[:warning], locale)

      localized_hash
    end

    def self.translate_and_substitute(translation_object, locale)
      return translation_object.map { |t| translate_and_substitute(t, locale) } if translation_object.is_a?(::Array)
      return translation_object unless translation_object.is_a?(::Hash)

      substitutions = translation_object[:substitutions]&.deep_dup || {}
      substitutions.transform_values! do |value|
        value.is_a?(::Hash) ? translate_and_substitute(value, locale) : value
      end

      if translation_object.key?(:path)
        path = translation_object[:path]
        path = "#{path}_html" if I18n.exists?("#{path}_html", locale:)
        ActiveSupport::SafeBuffer.new(I18n.t(path, **substitutions, locale:))
      elsif translation_object.key?(:method)
        view_helpers.send(
          translation_object[:method],
          *Array.wrap(translation_object[:value]),
          **substitutions, locale:
        )
      else
        translation_object.transform_values do |value|
          translate_and_substitute(value, locale)
        end
      end
    end

    def self.view_helpers
      @view_helpers ||= ApplicationController.new.helpers
    end
  end
end
