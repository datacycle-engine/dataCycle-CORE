# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContentFeatureTest < ActiveSupport::TestCase
    test 'content_objects allows querying active features' do
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1' }, prevent_history: true)

      assert(content.enabled_features.size.positive?)
    end

    test 'content_object without template' do
      content = DataCycleCore::Thing.new(template_name: 'Artikel')
      assert_raise NoMethodError do
        content.servas
      end

      assert_raise NotImplementedError do
        content.get_property_value('test', { 'test' => { 'label' => 'test', 'type' => 'test' } })
      end
    end

    test 'content_object has consistent data definitions' do
      content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { 'name' => 'HEADLINE 1' })

      assert(content == content.verify)
    end
  end
end
