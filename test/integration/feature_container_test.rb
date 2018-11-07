# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class FeatureContainerTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'LifeCycleTestArtikel' })
      @container = DataCycleCore::TestPreparations.create_content(template_name: 'Container', data_hash: { name: 'TestContainer' })
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'change life_cycle_stage to including children' do
      stages = DataCycleCore::Feature::LifeCycle.ordered_classifications(@container)

      @content.update({ is_part_of: @container.id })

      patch polymorphic_path([:update_life_cycle, @container]), params: {
        life_cycle: {
          id: stages.values.last[:id],
          name: stages.keys.last
        }
      }, headers: {
        referer: polymorphic_path(@container)
      }

      assert_redirected_to polymorphic_path(@container)
      follow_redirect!

      assert @container.reload.life_cycle_stage?(stages.values.last[:id])
      assert @content.reload.life_cycle_stage?(stages.values.last[:id])
    end
  end
end
