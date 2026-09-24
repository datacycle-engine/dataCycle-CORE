# frozen_string_literal: true

require 'test_helper'
require 'json'

module DataCycleCore
  module Api
    module V4
      module Content
        # [#51643] The marking of the generated attributes is delivered as part of 'contributor',
        # next to the agents an import or the editors linked - the injected 'contributor_generated'
        # appends into that key rather than adding one of its own.
        class GeneratedContributorTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
          include DataCycleCore::ApiV4Helper

          before(:all) do
            @routes = Engine.routes

            @editorial_agent = DataCycleCore::AiAgentService.find_or_create(
              DataCycleCore::Generic::Common::DataReferenceTransformations::AiAgentReference.new('odta:AIGenerated', 'Midjourney')
            )
            @image = DataCycleCore::TestPreparations.create_content(
              template_name: 'Generated-Image',
              data_hash: { 'name' => 'Lavendelfeld API', 'contributor' => [@editorial_agent.id] }
            )
            @image.update_computed_values(keys: ['description_generated'])
            @image.update_computed_values(keys: ['contributor_generated'])
            @image.reload
          end

          # Absolute counts elsewhere in the suite depend on no test leaving contents behind -
          # creative_work_history_test asserts Thing::History.count and filter_common_coverage_test
          # counts whole result sets - and this suite does not roll back between tests. The async
          # recompute also stores through a set_data_hash of its own, without the options of the save
          # that scheduled it, so it writes history whatever this test asks for.
          after(:all) do
            DataCycleCore::Thing
              .where(template_name: ['Generated-Image', DataCycleCore::AiAgentService::TEMPLATE_NAME])
              .destroy_all
            DataCycleCore::Thing::History::Translation.delete_all
            DataCycleCore::Thing::History.delete_all
          end

          setup do
            sign_in(User.find_by(email: 'tester@datacycle.at'))
          end

          # The v4 payload wraps the content in @graph.
          def serialized_image
            get api_v4_thing_path(id: @image.id)

            response.parsed_body['@graph'].first
          end

          test 'the generated marking is appended to the editorially linked contributors' do
            generated_id = @image.get_data_hash['contributor_generated'].first

            assert_not_nil(generated_id)
            assert_not_equal(@editorial_agent.id, generated_id)

            ids = Array.wrap(serialized_image['contributor']).pluck('@id')

            assert_equal(2, ids.size)
            assert_includes(ids, @editorial_agent.id)
            assert_includes(ids, generated_id)
          end

          test 'no contributorGenerated key of its own' do
            assert_not(serialized_image.key?('contributorGenerated'))
          end

          test 'the generated ALT label is delivered as description' do
            assert_equal('Lavendelfeld API', serialized_image['description'])
          end
        end
      end
    end
  end
end
