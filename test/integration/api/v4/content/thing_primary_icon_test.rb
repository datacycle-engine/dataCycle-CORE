# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

module DataCycleCore
  module Api
    module V4
      module Content
        # APIv4 rendering of the computed "Haupt-Icon" classification attribute
        # (primary_icon_classifications, ticket #44662) exposed as dc:icon.
        class ThingPrimaryIconTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          before(:all) do
            @routes = Engine.routes
            @tag2 = DataCycleCore::Concept.for_tree('Tags').with_name('Tag 2').first
            @markt2 = DataCycleCore::Concept.for_tree('Märkte').with_name('Markt 2').first

            DataCycleCore.stub(:classification_icons, { @tag2.id => 'tag2.svg', @markt2.id => 'markt2.svg' }) do
              @content = DataCycleCore::TestPreparations.create_content(
                template_name: 'PrimaryIcon-Place',
                data_hash: {
                  'name' => 'Primary Icon API Test',
                  'primary_icon_tags' => [@tag2.classification_id],
                  'primary_icon_maerkte' => [@markt2.classification_id]
                }
              )
              # primary_icon_classifications is computed async; run the recompute the job would do
              @content.update_computed_values(keys: ['primary_icon_classifications'])
            end
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          test 'dc:icon renders the primary icon concepts of both trees' do
            get api_v4_thing_path(id: @content.id)

            assert_response(:success)
            icons = response.parsed_body.dig('@graph', 0, 'dc:icon')

            assert_equal([@tag2.id, @markt2.id].sort, icons.pluck('@id').sort)
            assert(icons.all? { |i| i['@type'] == 'skos:Concept' })
          end

          test 'dc:icon exposes the per-concept icon url via fields expansion' do
            DataCycleCore.stub(:classification_icons, { @tag2.id => 'tag2.svg', @markt2.id => 'markt2.svg' }) do
              get api_v4_thing_path(id: @content.id, fields: 'dc:icon.@id,dc:icon.dc:icon')
            end

            assert_response(:success)
            icons = response.parsed_body.dig('@graph', 0, 'dc:icon')

            assert(icons.all? { |i| i['dc:icon'].to_s.end_with?('/icons/tag2.svg', '/icons/markt2.svg') })
          end
        end
      end
    end
  end
end
