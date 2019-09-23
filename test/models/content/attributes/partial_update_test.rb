# frozen_string_literal: true

require 'test_helper'
require 'minitest/spec'

module DataCycleCore
  module Content
    module Attributes
      class PartialUpdateTest < ActiveSupport::TestCase
        setup do
          @image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Test Bild 1' })
          @release_status_comment = 'Test Kommentar 1'
          @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'Test Artikel 1', release_status_comment: @release_status_comment, image: [@image.id] })
        end

        test 'partial update Artikel name' do
          new_data = { 'name' => 'Artikel' }
          sliced_template = @content.schema.dup
          sliced_template['properties'] = @content.schema['properties']&.slice(*new_data.keys)
          diff = @content.diff(new_data, sliced_template)
          assert_equal({ 'name' => ['~', 'Test Artikel 1', 'Artikel'] }, diff)

          @content.set_data_hash(data_hash: new_data, partial_update: true)
          assert_equal(@content.name, 'Artikel')
          assert_equal(1, @content.image.count)
        end

        test 'partial update Artikel name and Bild name' do
          @image.set_data_hash(data_hash: { 'name' => 'Bild' })
          @content.set_data_hash(data_hash: { 'name' => 'Artikel', 'image' => [@image.id] })
          assert_equal(@content.name, 'Artikel')
          assert_equal(@image.name, 'Bild')
          assert_equal(@content.image.first.name, 'Bild')
        end
      end
    end
  end
end
