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

        def translate_text(translate_hash)
          return {} if endpoint.blank? || translate_hash.blank? || translate_hash.values.all?(&:blank?)

          endpoint.translate(translate_hash.to_h)
        end
      end
    end
  end
end