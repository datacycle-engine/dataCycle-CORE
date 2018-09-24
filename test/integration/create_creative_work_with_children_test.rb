# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class CreativeWorksTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes

      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test 'create content inside container' do
      post creative_works_path, params: {
        creative_work: {
          datahash: {
            headline: 'Test Thema 1'
          }
        },
        table: 'creative_works',
        template: 'Thema'
      }

      parent = DataCycleCore::CreativeWork.find_by(headline: 'Test Thema 1')

      post creative_works_path, params: {
        creative_work: {
          datahash: {
            headline: 'Test Artikel 1'
          }
        },
        table: 'creative_works',
        template: 'Artikel',
        locale: 'de',
        parent_id: parent.id
      }

      child = DataCycleCore::CreativeWork.find_by(headline: 'Test Artikel 1')

      assert child
      assert_equal(child.parent.id, parent.id)
    end
  end
end
