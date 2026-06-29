# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Abilities
    # Coverage for the AttributeTranslation struct - pure logic that resolves attribute
    # key paths against a property-translations hash (shaped like
    # ThingTemplate.translated_property_names) and feeds the result to the translation
    # function. Exercises the nested-path resolution and both translation-function arities.
    class AttributeTranslationCoverageTest < DataCycleCore::TestCases::ActiveSupportTestCase
      Subject = DataCycleCore::Abilities::AttributeTranslation

      # { template_name => { property_key => { text:, type:, template:, embedded_template: } } }
      def property_translations
        {
          'Artikel' => {
            'image' => { text: 'Image', type: 'embedded', template: 'Bild', embedded_template: false },
            'desc' => { text: 'Description', type: 'string', template: nil, embedded_template: false }
          },
          'Bild' => {
            'name' => { text: 'Image Name', type: 'string', template: nil, embedded_template: false }
          }
        }
      end

      test 'resolve_keys walks a nested embedded path and joins the texts' do
        translation = Subject.new([['image', 'name'], 'desc'], 'Artikel', ->(data) { data })

        result = translation.resolve_keys(property_translations)

        assert_includes result, 'Image -> Image Name'
        assert_includes result, 'Description'
      end

      test 'resolve_keys passes the template name to a two-argument translation function' do
        translation = Subject.new(['desc'], 'Artikel', ->(data, template_name) { "#{data}::#{template_name}" })

        result = translation.resolve_keys(property_translations)

        assert_equal 'Description::Artikel', result
      end
    end
  end
end
