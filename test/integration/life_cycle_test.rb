# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class LifeCycleTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      @content = DataCycleCore::TestPreparations.create_content(template_name: 'Artikel with LifeCycle', data_hash: { name: 'LifeCycleTestArtikel' })
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'change life_cycle_stage to archive' do
      stages = DataCycleCore::Feature::LifeCycle.ordered_classifications(@content)

      patch polymorphic_path([:update_life_cycle, @content]), params: {
        life_cycle: {
          id: stages.values.last[:id],
          name: stages.keys.last
        }
      }, headers: {
        referer: thing_path(@content)
      }

      assert @content.life_cycle_stage?(stages.values.last[:id])
    end
  end
end
