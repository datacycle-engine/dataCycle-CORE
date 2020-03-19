# frozen_string_literal: true

module DataCycleCore
  module Feature
    class Translate < Base
      class << self
        def text_source(content)
          attribute_keys(content).first
        end

        def allowed_attribute_keys(content = nil)
          attribute_keys(content) || []
        end

        def external_source
          @external_source ||= DataCycleCore::ExternalSource.find_by(name: configuration.dig(:external_source))
        end

        def endpoint
          @endpoint ||= begin
            return if external_source.blank?

            configuration.dig(:endpoint).constantize.new(external_source.credentials.symbolize_keys)
          end
        end

        def translate_text(text_hash, locale = I18n.locale)
          return {} if endpoint.blank? || text_hash.blank? || text_hash.values.all?(&:blank?)

          endpoint.translate(text_hash.to_h, locale)
        end
      end
    end
  end
end
