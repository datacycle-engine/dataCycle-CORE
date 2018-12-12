# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class FeatureLifeCycleTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel', data_hash: { name: 'LifeCycleTestArtikel' })
      @stages = DataCycleCore::Feature::LifeCycle.ordered_classifications(@content)
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
  end
end
