# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  module Feature
    class LifeCycleTest < DataCycleCore::TestCases::ActionDispatchIntegrationTest
      before(:all) do
        @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'LifeCycleTestArtikel' })
        @stages = DataCycleCore::Feature::LifeCycle.ordered_classifications(@content)
      end

      setup do
        sign_in(User.find_by(email: 'tester@datacycle.at'))
      end

      test 'change life_cycle_stage to archive' do
        patch update_life_cycle_thing_path(@content), params: {
          life_cycle: {
            id: @stages.values.last[:id],
            name: @stages.keys.last
          }
        }, headers: {
          referer: thing_path(@content)
        }

        assert_redirected_to thing_path(@content)
        follow_redirect!

        assert @content.reload.life_cycle_stage?(@stages.values.last[:id])
      end

      test 'change life_cycle_stage to idea_collection stage' do
        @container = DataCycleCore::TestPreparations.create_content(template_name: 'Container', data_hash: { name: 'LifeCycleTestContainer' })

        patch update_life_cycle_thing_path(@container), params: {
          life_cycle: {
            id: DataCycleCore::Feature::IdeaCollection.life_cycle_stage,
            name: DataCycleCore::Feature::IdeaCollection.life_cycle_stage_name
          }
        }, headers: {
          referer: thing_path(@container)
        }

        assert_redirected_to thing_path(@container)
        follow_redirect!

        assert @container.reload.life_cycle_stage?(DataCycleCore::Feature::IdeaCollection.life_cycle_stage)
      end
    end
  end
end
