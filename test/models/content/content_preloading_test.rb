# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    class ContentPreloadingTest < DataCycleCore::TestCases::ActiveSupportTestCase
      include DataCycleCore::ActiveStorageHelper

      before(:all) do
        file_name = 'test_rgb_portrait.jpeg'
        @asset = upload_image(file_name)

        @author = DataCycleCore::TestPreparations.create_content(template_name: 'Organization', data_hash: { name: 'Testauthor 1' })
        @image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Testbild', author: [@author.id], asset: @asset.id })
        @image2 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Testbild 2', author: [@author.id] })
        @image3 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Testbild 3', author: [@author.id] })
        @tag = DataCycleCore::Classification.for_tree('Tags').first
        @pois = []

        5.times do |i|
          @pois.push(DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: "POI #{i}", image: [@image.id, @image3.id, @image2.id], tags: [@tag.id], additional_information: [{
            name: 'Test embedded',
            description: 'embedded description Test'
          }] }))
        end

        @pois[2].set_data_hash(data_hash: { overlay: [{ image: [@image2.id] }] })
        @pois[3].set_data_hash(data_hash: { overlay: [{ name: 'Overwritten POI Name' }] })
        @author.set_data_hash(data_hash: { content_location: [@pois[1].id] })
      end

      test 'set @_current_collection on relation load' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5)

        contents.each do |content|
          assert(content.current_collection?)
          assert_equal(contents, content.instance_variable_get(:@_current_collection))
        end
      end

      test 'image relation is preloaded after first call' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5)
        contents.first.image

        contents.each do |content|
          assert(content.image.loaded?)
          assert_equal(3, content.image.size)
          assert_equal([@image.id, @image3.id, @image2.id], content.image.pluck(:id))
        end
      end

      test 'overlay relation is preloaded after first call' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5)
        contents.first.overlay

        contents.each do |content|
          assert(content.overlay.loaded? || content.overlay.is_a?(ActiveRecord::NullRelation))
        end

        assert_equal(1, @pois[2].overlay.size)
        assert_equal(1, @pois[3].overlay.size)
      end

      test 'image relation is preloaded after first call with image_overlay' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5)
        contents.instance_variable_set(:@_debugger_stop, true)
        contents = contents.to_a
        contents.first.image_overlay

        contents.each do |content|
          assert(content.image_overlay.loaded?)
          assert(content.image.loaded?)
        end

        poi2 = contents.detect { |c| c.id == @pois[2].id }

        assert(poi2.overlay.loaded?)
        assert(poi2.overlay.first.image.loaded?)

        assert_equal([@image2.id], poi2.image_overlay.pluck(:id))
        assert_equal([@image.id, @image3.id, @image2.id], poi2.image.pluck(:id))
      end

      test 'recursive_content_links with depth of 0 -> full recursive' do
        assert_equal(12, @pois[0].recursive_content_links.size)
        assert_equal(8, @pois[1].recursive_content_links.size)
        assert_equal(14, @pois[2].recursive_content_links.size)
        assert_equal(13, @pois[3].recursive_content_links.size)
        assert_equal(12, @pois[4].recursive_content_links.size)
      end

      test 'recursive_content_links with depth of 1' do
        assert_equal([@image.id, @image3.id, @image2.id], @pois[0].recursive_content_links(depth: 1).filter { |cc| cc.relation_a == 'image' }.pluck(:content_b_id))
        assert_equal([@image.id, @image3.id, @image2.id], @pois[1].recursive_content_links(depth: 1).filter { |cc| cc.relation_a == 'image' }.pluck(:content_b_id))
        assert_equal([@image.id, @image3.id, @image2.id], @pois[4].recursive_content_links(depth: 1).filter { |cc| cc.relation_a == 'image' }.pluck(:content_b_id))

        assert_equal(6, @pois[2].recursive_content_links(depth: 1).size)
        assert_equal(5, @pois[2].recursive_content_links(depth: 1).count(&:leaf))
        assert_equal(5, @pois[3].recursive_content_links(depth: 1).size)
        assert_equal(4, @pois[3].recursive_content_links(depth: 1).count(&:leaf))
      end

      test 'recursive_content_links with depth of 2' do
        assert_equal(7, @pois[0].recursive_content_links(depth: 2).size)
        assert_equal(7, @pois[1].recursive_content_links(depth: 2).size)
        assert_equal(9, @pois[2].recursive_content_links(depth: 2).size)
        assert_equal(8, @pois[3].recursive_content_links(depth: 2).size)
        assert_equal(7, @pois[4].recursive_content_links(depth: 2).size)
      end

      test 'tags relation is preloaded after first call' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5)
        contents.first.tags

        contents.each do |content|
          assert(content.tags.loaded?)
          assert_equal(1, content.tags.size)
          assert_equal([@tag.id], content.tags.pluck(:id))
        end
      end

      test 'additional_information relation is preloaded after first call' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5)
        contents.first.additional_information

        contents.each do |content|
          assert(content.additional_information.loaded?)
          assert_equal(1, content.additional_information.size)
        end
      end

      test 'asset relation is preloaded after first call' do
        contents = DataCycleCore::Thing.where(template_name: 'Bild').limit(5)
        contents.first.asset

        image = contents.detect { |c| c.id == @image.id }
        assert(image.asset.present?)
      end

      test 'preload depth of 1 is recognized' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5)
        contents.instance_variable_set(:@_recursive_preload_depth, 1)
        contents.load

        contents.each do |content|
          assert(content.image.loaded?)
          assert(content.image.first.author.loaded?) # preloads relations for all leafs
        end
      end

      test 'preload depth of 2 is recognized' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5)
        contents.instance_variable_set(:@_recursive_preload_depth, 2)

        contents.each do |content|
          assert(content.image.loaded?)
          assert(content.image.first.author.loaded?)
        end
      end
    end
  end
end
