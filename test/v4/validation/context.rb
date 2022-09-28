# frozen_string_literal: true

module DataCycleCore
  module V4
    module Validation
      class Context
        CONTEXT_ATTRIBUTES = Dry::Schema.JSON do
          required(:'@base').value(:string)
          required(:skos) { eql?('https://www.w3.org/2009/08/skos-reference/skos.html#') }
          required(:dct) { eql?('http://purl.org/dc/terms/') }
          required(:cc) { eql?('http://creativecommons.org/ns#') }
          required(:dc) { eql?('https://schema.datacycle.at/') }
          required(:dcls).value(:string)
          required(:odta) { eql?('https://odta.io/voc/') }
        end

        def self.build_language_attributes(languages)
          return Dry::Schema.JSON if languages.present? && languages.split(',').size > 1
          language = ['de', 'en'].include?(languages) ? languages : 'de'
          Dry::Schema.JSON do
            required(:'@language') { eql?(language) }
          end
        end

        def self.context(languages = nil)
          language_attributes = build_language_attributes(languages)
          validator = Dry::Validation.Contract do
            config.validate_keys = true
            json(CONTEXT_ATTRIBUTES, language_attributes)
          end
          validator
        end
      end
    end
  end
end
