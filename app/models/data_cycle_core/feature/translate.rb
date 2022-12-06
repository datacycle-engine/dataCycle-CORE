# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Translate < Base
      class << self
        def controller_module
          DataCycleCore::Feature::ControllerFunctions::Translate
        end

        def text_source(content)
          attribute_keys(content).first
        end

        def allowed_attribute_keys(content = nil)
          attribute_keys(content) || []
        end

        def allowed?(content, locale, source_locale, user)
          super(content) && allowed_languages.include?(locale.to_s) && allowed_languages.include?(source_locale.to_s) && user&.can?(:translate, content)
        end

        def external_source
          @external_source ||= DataCycleCore::ExternalSystem.find_by(name: configuration.dig(:external_source))
        end

        def endpoint
          @endpoint ||= (configuration.dig(:endpoint).constantize.new(**external_source.credentials.symbolize_keys) if external_source.present?)
        end

        def translate_text(translate_hash)
          return {} if endpoint.blank? || translate_hash.blank? || translate_hash.values.all?(&:blank?) || translate_hash['text'].blank?

          endpoint.translate(translate_hash.to_h)
        end

        def allowed_attribute?(content, key, locale)
          enabled? && allowed_languages.include?(locale.to_s) && configuration(content, key).dig(:inline)
        end

        def allowed_languages
          Array.wrap(configuration[:allowed_languages])
        end
      end
    end
  end
end
