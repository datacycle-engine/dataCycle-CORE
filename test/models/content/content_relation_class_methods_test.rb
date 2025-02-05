# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Content
    class ContentRelationClassMethodsTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @image = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Testbild' })
        @image2 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Testbild 2' })
        @image3 = DataCycleCore::TestPreparations.create_content(template_name: 'Bild', data_hash: { name: 'Testbild 3' })
        @tag = DataCycleCore::Classification.for_tree('Tags').first
        @pois = []

        5.times do |i|
          @pois.push(DataCycleCore::TestPreparations.create_content(template_name: 'POI', data_hash: { name: "POI #{i}", image: [@image.id, @image3.id, @image2.id], tags: [@tag.id] }))
        end

        @pois[2].set_data_hash(data_hash: { overlay: [{ image: [@image2.id] }] })
        @pois[3].set_data_hash(data_hash: { overlay: [{ name: 'Overwritten POI Name' }] })
      end

      test 'content_content_a relation is not preloaded' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5)
        ccs = contents.content_content_a

        assert(ccs.is_a?(ActiveRecord::Relation))
        assert_not(ccs.loaded?)
        assert_equal(17, ccs.size)
      end

      test 'content_content_a relation is not preloaded, but contents are loaded' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5)
        ccs = contents.content_content_a

        assert(ccs.is_a?(ActiveRecord::Relation))
        assert_not(ccs.loaded?)
        assert_equal(17, ccs.size)
      end

      test 'content_content_a relation is preloaded' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5).preload(:content_content_a).load
        ccs = contents.content_content_a

        assert(ccs.is_a?(ActiveRecord::Relation))
        assert(ccs.loaded?)
        assert_equal(17, ccs.size)
      end

      test 'content_content_a relation is null_relation' do
        contents = DataCycleCore::Thing.none
        ccs = contents.content_content_a

        assert(ccs.is_a?(ActiveRecord::Relation))
        assert_equal(0, ccs.size)
      end

      test 'get thing_templates for all POIs' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5)
        templates = contents.thing_templates

        assert(templates.is_a?(ActiveRecord::Relation))
        assert_not(templates.loaded?)
        assert_equal(1, templates.size)
      end

      test 'get thing_templates for all POIs, contents loaded' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5).load
        templates = contents.thing_templates

        assert(templates.is_a?(ActiveRecord::Relation))
        assert(templates.loaded?) # thing_template is included via default_scope
        assert_equal(1, templates.size)
      end

      test 'get thing_templates for all POIs, thing_templates preloaded' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5).preload(:thing_template).load
        templates = contents.thing_templates

        assert(templates.is_a?(ActiveRecord::Relation))
        assert(templates.loaded?)
        assert_equal(1, templates.size)
      end

      test 'get only images for all POIs, with custom scope' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5)
        ccs = contents.load_relation(relation_name: :content_content_a, scope: DataCycleCore::ContentContent.where(content_a_id: contents.pluck(:id), relation_a: 'image'))

        assert(ccs.is_a?(ActiveRecord::Relation))
        assert_not(ccs.loaded?)
        assert_equal(15, ccs.size)
      end

      test 'get only images for all POIs, with custom scope and preload' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5).load
        ccs = contents.load_relation(relation_name: :content_content_a, scope: DataCycleCore::ContentContent.where(content_a_id: contents.pluck(:id), relation_a: 'image'), preload: true)

        assert(ccs.is_a?(ActiveRecord::Relation))
        assert_not(ccs.loaded?)
        assert_equal(15, ccs.size)
        assert_not(contents.first.content_content_a.loaded?)
      end

      test 'get only images for all POIs, with custom scope, preloaded content_content_a' do
        contents = DataCycleCore::Thing.where(template_name: 'POI').limit(5).preload(:content_content_a).load
        ccs = contents.load_relation(relation_name: :content_content_a, scope: DataCycleCore::ContentContent.where(content_a_id: contents.pluck(:id), relation_a: 'image'))

        assert(ccs.is_a?(ActiveRecord::Relation))
        assert_not(ccs.loaded?)
        assert_equal(15, ccs.size)
      end
    end
  end
end
