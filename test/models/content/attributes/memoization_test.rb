# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    module Attributes
      class MemoizationTest < ActiveSupport::TestCase
        setup do
          @image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })
          @release_status_comment = 'Test Kommentar 1'
          @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1', release_status_comment: @release_status_comment, image: [@image.id] })
        end

        test 'reload attributes if updated' do
          assert_equal @image.id, @content.image.first.id
          image2 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 2' })

          @content.set_data_hash(data_hash: { image: [image2.id] }, partial_update: true)

          assert_equal image2.id, @content.image.first.id
        end

        test 'reload attributes if set via partial_update' do
          assert_equal @release_status_comment, @content.release_status_comment

          new_comment = 'Test Kommentar 2'

          @content.set_data_hash(data_hash: { 'release_status_comment' => new_comment }, prevent_history: true, partial_update: true)

          assert_equal new_comment, @content.release_status_comment
        end

        test 'set memoized plain_property_names' do
          @content.set_memoized_attribute('name', 'test-string-0')
          assert_equal('test-string-0', @content.send(:name))
        end

        test 'set memoized linked_property_names and embedded_property_names' do
          value1 = DataCycleCore::Thing.limit(1).offset(0)
          @content.set_memoized_attribute('image', value1)
          assert_equal(value1, @content.send(:image))

          value2 = DataCycleCore::Thing.limit(1).offset(1)
          @content.set_memoized_attribute('potential_action', value2)
          assert_equal(value2, @content.send(:potential_action))
        end

        test 'set memoized classification_property_names' do
          value = DataCycleCore::Classification.limit(1).offset(0)
          @content.set_memoized_attribute('tags', value)
          assert_equal(value, @content.send(:tags))
        end
      end
    end
  end
end
