# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Translate < Base
      class << self
        def controller_module
          DataCycleCore::Feature::ControllerFunctions::Translate
        end

        def routes_module
          DataCycleCore::Feature::Routes::Translate
        end

        def text_source(content)
          attribute_keys(content).first
        end

        def allowed_attribute_keys(content = nil)
          attribute_keys(content) || []
        end

        def allowed?(content, locale, source_locale, user)
          super(content) && target_locale_allowed?(locale) && source_locale_allowed?(source_locale) && user&.can?(:translate, content)
        end

        def external_source
          @external_source ||= DataCycleCore::ExternalSystem.find_by(name: configuration[:external_source])
        end

        def endpoint
          @endpoint ||= (configuration[:endpoint].constantize.new(**external_source.credentials.symbolize_keys) if external_source.present?)
        end

        def translate_text(translate_hash)
          return {} if endpoint.blank? || translate_hash.blank? || translate_hash.values.all?(&:blank?) || translate_hash['text'].blank?

          endpoint.translate(translate_hash.to_h)
        end

        def allowed_attribute?(content, key, locale, user)
          enabled? && target_locale_allowed?(locale) && configuration(content, key)[:inline] && user&.can?(:translate, content)
        end

        def allowed_target_languages
          return [] if external_source.blank?

          allowed_target_languages = configuration[:endpoint].safe_constantize.try(:allowed_target_languages) || I18n.available_locales

          allowed_target_languages.map(&:to_s) & I18n.available_locales.map(&:to_s)
        end

        def allowed_source_languages
          return [] if external_source.blank?

          allowed_source_languages = configuration[:endpoint].safe_constantize.try(:allowed_source_languages) || I18n.available_locales

          allowed_source_languages.map(&:to_s) & I18n.available_locales.map(&:to_s)
        end

        def target_locale_allowed?(locale)
          allowed_target_languages.intersect?([locale.to_s, locale.to_s.split('-').first])
        end

        def source_locale_allowed?(locale)
          allowed_source_languages.intersect?([locale.to_s, locale.to_s.split('-').first])
        end
      end
    end
  end
end
