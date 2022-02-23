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
          @content.plain_property_names.except('id').each.with_index do |property_name, index|
            @content.set_memoized_attribute(property_name, "test-string-#{index}")

            assert_equal("test-string-#{index}", @content.send(property_name))
          end
        end

        test 'set memoized linked_property_names and embedded_property_names' do
          (@content.linked_property_names + @content.embedded_property_names).each.with_index do |property_name, index|
            value = DataCycleCore::Thing.where(template: false).limit(1).offset(index)

            @content.set_memoized_attribute(property_name, value)

            assert_equal(value, @content.send(property_name))
          end
        end

        test 'set memoized classification_property_names' do
          @content.classification_property_names.each.with_index do |property_name, index|
            value = DataCycleCore::Classification.limit(1).offset(index)

            @content.set_memoized_attribute(property_name, value)

            assert_equal(value, @content.send(property_name))
          end
        end
      end
    end
  end
end
