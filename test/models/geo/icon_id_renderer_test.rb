# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

module DataCycleCore
  module Geo
    # Executes the dc:iconId include of the shared Geo::BaseRenderer against real
    # data: a content with a stored computed primary_icon_classifications value is
    # rendered through the GeojsonRenderer (parseable output) and the MvtRenderer.
    class IconIdRendererTest < DataCycleCore::TestCases::ActiveSupportTestCase
      before(:all) do
        @tag2 = DataCycleCore::Concept.for_tree('Tags').with_name('Tag 2').first
        @nested_tag = DataCycleCore::Concept.for_tree('Tags').with_name('Nested Tag 1').first
        @markt2 = DataCycleCore::Concept.for_tree('Märkte').with_name('Markt 2').first

        icons = { @tag2.id => 'tag2.svg', @nested_tag.id => 'nested.svg', @markt2.id => 'markt2.svg' }

        DataCycleCore.stub(:classification_icons, icons) do
          @content = DataCycleCore::TestPreparations.create_content(
            template_name: 'PrimaryIcon-Place',
            data_hash: {
              'name' => 'Icon Id Test',
              'location' => RGeo::Geographic.spherical_factory(srid: 4326).point(11.4, 47.26),
              'primary_icon_tags' => [@tag2.classification_id],
              'primary_icon_maerkte' => [@markt2.classification_id]
            }
          )

          @nested_content = DataCycleCore::TestPreparations.create_content(
            template_name: 'PrimaryIcon-Place',
            data_hash: {
              'name' => 'Icon Id Nested Test',
              'location' => RGeo::Geographic.spherical_factory(srid: 4326).point(11.5, 47.3),
              'primary_icon_tags' => [@nested_tag.classification_id]
            }
          )

          # primary_icon_classifications is computed async; run the recompute the job would do
          [@content, @nested_content].each { |c| c.update_computed_values(keys: ['primary_icon_classifications']) }
        end
      end

      def geojson_icon_id(content, **)
        JSON.parse(content.to_geojson(include_parameters: [['dc:iconId']], **)).dig('properties', 'dc:iconId')
      end

      test 'geojson contains dc:iconId as csv of the primary icons of both trees' do
        icon_ids = geojson_icon_id(@content)

        assert_equal([@tag2.id, @markt2.id].sort, icon_ids.split(',').sort)
      end

      test 'filtered on one tree dc:iconId is a single id' do
        tags_tree_id = DataCycleCore::ClassificationTreeLabel.find_by(name: 'Tags').id

        assert_equal(@tag2.id, geojson_icon_id(@content, classification_trees_parameters: [tags_tree_id]))
      end

      test 'transitive broader rows do not leak into dc:iconId' do
        # 'Nested Tag 1' stores a 'broader' row for its parent 'Tag 3' in the same relation
        assert_equal(@nested_tag.id, geojson_icon_id(@nested_content))
      end

      test 'contents without primary icons render a null dc:iconId' do
        content = DataCycleCore::TestPreparations.create_content(
          template_name: 'PrimaryIcon-Place',
          data_hash: {
            'name' => 'Icon Id Empty Test',
            'location' => RGeo::Geographic.spherical_factory(srid: 4326).point(11.6, 47.4)
          }
        )

        assert_nil(geojson_icon_id(content))
      end

      test 'mvt tile renders with dc:iconId included' do
        mvt = DataCycleCore::Geo::MvtRenderer.new(
          0, 0, 0,
          contents: DataCycleCore::Thing.where(id: @content.id),
          include_parameters: [['dc:iconId']]
        ).render

        assert_predicate(mvt, :present?)
      end
    end
  end
end
