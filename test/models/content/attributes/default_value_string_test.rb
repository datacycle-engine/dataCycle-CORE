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
        end

        test 'default strings get set on new contents' do
          set_default_value('Artikel', 'alternative_headline', 'alternative_headline_1')
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' })

          assert_equal 'alternative_headline_1', content.alternative_headline
        end

        test 'default strings dont override existing values on new contents' do
          set_default_value('Artikel', 'alternative_headline', 'alternative_headline_1')
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1', alternative_headline: 'alternative_headline_2' })

          assert_equal 'alternative_headline_2', content.alternative_headline
        end

        test 'default strings dont get set on existing contents with partial update' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' })

          set_default_value('Artikel', 'alternative_headline', 'alternative_headline_1', content)

          content.set_data_hash(data_hash: { name: 'Test Artikel 2' }, update_search_all: false, prevent_history: true, partial_update: true)

          assert content.alternative_headline.blank?
          assert_equal 'Test Artikel 2', content.name
        end

        test 'default strings get overriden by blank values on existing contents with partial update' do
          set_default_value('Artikel', 'alternative_headline', 'alternative_headline_1')
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' })

          assert_equal 'alternative_headline_1', content.alternative_headline

          content.set_data_hash(data_hash: { name: 'Test Artikel 2', alternative_headline: nil }, update_search_all: false, prevent_history: true, partial_update: true)

          assert content.alternative_headline.blank?
          assert_equal 'Test Artikel 2', content.name
        end

        test 'default strings dont get updated on existing contents with partial update' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1', alternative_headline: 'alternative_headline_2' })

          set_default_value('Artikel', 'alternative_headline', 'alternative_headline_1', content)

          content.set_data_hash(data_hash: { name: 'Test Artikel 2' }, update_search_all: false, prevent_history: true, partial_update: true)

          assert_equal 'alternative_headline_2', content.alternative_headline
          assert_equal 'Test Artikel 2', content.name
        end

        test 'default strings dont get set on existing contents with normal update' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' })

          set_default_value('Artikel', 'alternative_headline', 'alternative_headline_1', content)

          content.set_data_hash(data_hash: { name: 'Test Artikel 2' }, update_search_all: false, prevent_history: true)

          assert content.alternative_headline.blank?
          assert_equal 'Test Artikel 2', content.name
        end

        test 'default strings dont get updated on existing contents with normal update' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1', alternative_headline: 'alternative_headline_2' })

          set_default_value('Artikel', 'alternative_headline', 'alternative_headline_1', content)

          content.set_data_hash(data_hash: { name: 'Test Artikel 2' }, update_search_all: false, prevent_history: true)

          assert content.alternative_headline.blank?
          assert_equal 'Test Artikel 2', content.name
        end
      end
    end
  end
end
