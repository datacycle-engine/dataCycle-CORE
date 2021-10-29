# frozen_string_literal: true

module DataCycleCore
  module Generic
    module DeeplTranslate
      class DummyEndpoint < DataCycleCore::Generic::DeeplTranslate::Endpoint
        # Format translate_hash: { 'text' => 'Hallo', 'source_locale' => 'de', 'target_locale' => 'en' }
        # Format return data: nil | { 'detected_source_language' => 'DE', 'text' => 'Hello' }
        def translate(translate_hash)
          return if translate_hash.blank?
          return unless translate_hash.is_a?(::Hash) || translate_hash.is_a?(DataCycleCore::OpenStructHash)

          {
            'detected_source_language' => translate_hash['source_locale'].upcase,
            'text' => "#{translate_hash['target_locale']}: source_locale=#{translate_hash['source_locale']}"
          }
        end
      end
    end
  end
end
