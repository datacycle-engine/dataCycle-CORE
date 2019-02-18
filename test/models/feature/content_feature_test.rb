# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class ContentFeatureTest < ActiveSupport::TestCase
    test 'content_objects allows querying active features' do
      content = DataCycleCore::Thing.new
      assert(content.enabled_features.size.positive?)
    end

    test 'content_object without template' do
      content = DataCycleCore::Thing.new
      assert_raise NoMethodError do
        content.servas
      end

      assert_raise NotImplementedError do
        content.get_property_value('test', { 'test' => { 'label' => 'test', 'type' => 'test' } })
      end
    end

    test 'content_object has consistent data definitions' do
      content = DataCycleCore::TestPreparations.data_set_object('Artikel')
      content.save!
      content.set_data_hash(data_hash: { 'name' => 'HEADLINE 1' })
      content.save!
      assert(content == content.verify)
    end
  end
end
