# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    module Attributes
      class DefaultValueClassificationTest < ActiveSupport::TestCase
        def set_default_value(template_name, key, value, content = nil)
          template = content || DataCycleCore::Thing.find_by(template: true, template_name: template_name)
          if value.nil?
            template.schema['properties'][key].delete('default_value')
          else
            template.schema['properties'][key]['default_value'] = value
          end
          template.save
        end

        test 'default classifications get set on new contents' do
          classification_id = DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Inhaltstypen', 'Artikel')

          content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' })

          assert_equal classification_id, content.data_type.ids.first
        end

        test 'default classifications dont override existing values on new contents' do
          classification_id = DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Inhaltstypen', 'Bild')

          content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1', data_type: [classification_id] })

          assert_equal classification_id, content.data_type.ids.first
        end

        test 'default classifications dont get set on existing contents with partial update' do
          set_default_value('Artikel', 'data_type', nil)

          content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' })

          set_default_value('Artikel', 'data_type', 'Artikel', content)

          content.set_data_hash(data_hash: { name: 'Test Artikel 2' }, update_search_all: false, prevent_history: true, partial_update: true)

          assert content.data_type.blank?
          assert_equal 'Test Artikel 2', content.name
        end

        test 'default classifications get overriden by blank values on existing contents with partial update' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' })

          content.set_data_hash(data_hash: { name: 'Test Artikel 2', data_type: nil }, update_search_all: false, prevent_history: true, partial_update: true)

          assert content.data_type.blank?
          assert_equal 'Test Artikel 2', content.name
        end

        test 'default classifications dont get updated on existing contents with partial update' do
          classification_id = DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Inhaltstypen', 'Bild')

          content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1', data_type: [classification_id] })

          content.set_data_hash(data_hash: { name: 'Test Artikel 2' }, update_search_all: false, prevent_history: true, partial_update: true)

          assert_equal classification_id, content.data_type.ids.first
          assert_equal 'Test Artikel 2', content.name
        end

        test 'default classifications dont get set on existing contents with normal update' do
          set_default_value('Artikel', 'data_type', nil)

          content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' })

          set_default_value('Artikel', 'data_type', 'Artikel', content)

          content.set_data_hash(data_hash: { name: 'Test Artikel 2' }, update_search_all: false, prevent_history: true)

          assert content.data_type.blank?
          assert_equal 'Test Artikel 2', content.name
        end

        test 'default classifications dont get used for update on existing contents with normal update' do
          classification_id = DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Inhaltstypen', 'Bild')

          content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1', data_type: [classification_id] })
          content.set_data_hash(data_hash: { name: 'Test Artikel 2' }, update_search_all: false, prevent_history: true)

          assert content.data_type.blank?
          assert_equal 'Test Artikel 2', content.name
        end

        test 'default classifications dont get used for new translations, as classifications are not translatable' do
          content = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })
          classification_id = DataCycleCore::ClassificationAlias.classification_for_tree_with_name('Inhaltstypen', 'Bild')

          assert_equal classification_id, content.data_type.ids.first

          set_default_value('Bild', 'data_type', 'Artikel', content)

          I18n.with_locale(:en) do
            content.set_data_hash(data_hash: { name: 'Test Bild 2' }, update_search_all: false, prevent_history: true, partial_update: true)

            assert_equal classification_id, content.data_type.ids.first
            assert_equal 'Test Bild 2', content.name
          end
        end
      end
    end
  end
end
