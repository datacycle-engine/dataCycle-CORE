# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class DefaultValueStringTest < ActiveSupport::TestCase
        def set_default_value(template_name, key, value, content = nil)
          template = content || DataCycleCore::Thing.find_by(template: true, template_name: template_name)
          template.schema['properties'][key]['default_value'] = value
          template.save
          template.remove_instance_variable(:@default_value_property_names) if template.instance_variable_defined?(:@default_value_property_names)
        end

        test 'default strings get set on new contents' do
          set_default_value('Bild', 'alternative_headline', 'alternative_headline_1')
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })

          assert_equal 'alternative_headline_1', content.alternative_headline
        end

        test 'single default strings' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })

          set_default_value('Bild', 'alternative_headline', 'alternative_headline_1', content)

          value = content.default_value('alternative_headline', nil, {})

          assert_equal 'alternative_headline_1', value
          assert_equal 'alternative_headline_1', content.alternative_headline
        end

        test 'default strings dont override existing values on new contents' do
          set_default_value('Bild', 'alternative_headline', 'alternative_headline_1')
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', alternative_headline: 'alternative_headline_2' })

          assert_equal 'alternative_headline_2', content.alternative_headline
        end

        test 'default strings dont get set on existing contents with partial update' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })

          set_default_value('Bild', 'alternative_headline', 'alternative_headline_1', content)

          content.set_data_hash(data_hash: { name: 'Test Bild 2' }, update_search_all: false, prevent_history: true, partial_update: true)

          assert content.alternative_headline.blank?
          assert_equal 'Test Bild 2', content.name
        end

        test 'default strings get overriden by blank values on existing contents with partial update' do
          set_default_value('Bild', 'alternative_headline', 'alternative_headline_1')
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })

          assert_equal 'alternative_headline_1', content.alternative_headline

          content.set_data_hash(data_hash: { name: 'Test Bild 2', alternative_headline: nil }, update_search_all: false, prevent_history: true, partial_update: true)

          assert content.alternative_headline.blank?
          assert_equal 'Test Bild 2', content.name
        end

        test 'default strings dont get updated on existing contents with partial update' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', alternative_headline: 'alternative_headline_2' })

          set_default_value('Bild', 'alternative_headline', 'alternative_headline_1', content)

          content.set_data_hash(data_hash: { name: 'Test Bild 2' }, update_search_all: false, prevent_history: true, partial_update: true)

          assert_equal 'alternative_headline_2', content.alternative_headline
          assert_equal 'Test Bild 2', content.name
        end

        test 'default strings dont get set on existing contents with normal update' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })

          set_default_value('Bild', 'alternative_headline', 'alternative_headline_1', content)

          content.set_data_hash(data_hash: { name: 'Test Bild 2' }, update_search_all: false, prevent_history: true)

          assert content.alternative_headline.blank?
          assert_equal 'Test Bild 2', content.name
        end

        test 'default strings dont get updated on existing contents with normal update' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', alternative_headline: 'alternative_headline_2' })

          set_default_value('Bild', 'alternative_headline', 'alternative_headline_1', content)

          content.set_data_hash(data_hash: { name: 'Test Bild 2' }, update_search_all: false, prevent_history: true)

          assert content.alternative_headline.blank?
          assert_equal 'Test Bild 2', content.name
        end

        test 'default strings get set on new translation' do
          set_default_value('Bild', 'alternative_headline', 'alternative_headline_1')
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })

          assert_equal 'alternative_headline_1', content.alternative_headline

          I18n.with_locale(:en) do
            content.set_data_hash(data_hash: { name: 'Test Bild 2' }, update_search_all: false, prevent_history: true, partial_update: true)

            assert_equal 'alternative_headline_1', content.alternative_headline
          end
        end

        test 'default strings dont override existing values on new translation' do
          set_default_value('Bild', 'alternative_headline', 'alternative_headline_1')
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1', alternative_headline: 'alternative_headline_2' })

          assert_equal 'alternative_headline_2', content.alternative_headline

          I18n.with_locale(:en) do
            content.set_data_hash(data_hash: { name: 'Test Bild 2', alternative_headline: 'alternative_headline_2' }, update_search_all: false, prevent_history: true, partial_update: true)

            assert_equal 'alternative_headline_2', content.alternative_headline
          end
        end

        test 'default strings get set in embedded with translated: true on new contents' do
          set_default_value('Embedded-With-Default-1', 'test_text_attribute', 'text_1')

          content = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-With-Default-1', data_hash: {
            name: 'Test Embedded-Entity-With-Default-1 1',
            embedded_creative_work: [
              {
                test_attribute: 'test1'
              }
            ]
          })

          assert_equal 'test1', content.embedded_creative_work.first.test_attribute
          assert_equal 'text_1', content.embedded_creative_work.first.test_text_attribute
        end

        test 'default strings dont get set in embedded with translated: true on update' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-With-Default-1', data_hash: {
            name: 'Test Embedded-Entity-With-Default-1 1',
            embedded_creative_work: [
              {
                test_attribute: 'test1'
              }
            ]
          })

          set_default_value('Embedded-With-Default-1', 'test_text_attribute', 'text_1')

          content.set_data_hash(data_hash: {
            name: 'Test Embedded-Entity-With-Default-1 2', embedded_creative_work: [
              {
                id: content.embedded_creative_work.first.id,
                test_attribute: 'test2'
              }
            ]
          }, update_search_all: false, prevent_history: true, partial_update: true)

          assert_equal 'test2', content.embedded_creative_work.first.test_attribute
          assert content.embedded_creative_work.first.test_text_attribute.blank?
        end

        test 'default strings get set in embedded on new contents' do
          set_default_value('Embedded-With-Default-2', 'test_text_attribute', 'text_1')

          content = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-With-Default-2', data_hash: {
            name: 'Test Embedded-Entity-With-Default-2 1',
            embedded_creative_work: [
              {
                test_attribute: 'test1'
              }
            ]
          })

          assert_equal 'test1', content.embedded_creative_work.first.test_attribute
          assert_equal 'text_1', content.embedded_creative_work.first.test_text_attribute
        end

        test 'default strings dont get set in embedded on update' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Embedded-Entity-With-Default-2', data_hash: {
            name: 'Test Embedded-Entity-With-Default-2 1',
            embedded_creative_work: [
              {
                test_attribute: 'test1'
              }
            ]
          })

          set_default_value('Embedded-With-Default-2', 'test_text_attribute', 'text_1')

          content.set_data_hash(data_hash: {
            name: 'Test Embedded-Entity-With-Default-2 2', embedded_creative_work: [
              {
                id: content.embedded_creative_work.first.id,
                test_attribute: 'test2'
              }
            ]
          }, update_search_all: false, prevent_history: true, partial_update: true)

          assert_equal 'test2', content.embedded_creative_work.first.test_attribute
          assert content.embedded_creative_work.first.test_text_attribute.blank?
        end
      end
    end
  end
end
