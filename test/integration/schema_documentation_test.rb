# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class SchemaDocumentationTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
      sign_in(User.find_by(email: 'tester@datacycle.at'))
    end

    test '/schema provides list of available templates' do
      get '/schema'

      assert_response :success

      assert_select 'ul.container_templates > li', {
        count: DataCycleCore::Thing.where(template: true).where("schema ->> 'content_type' = 'container'").count
      }

      assert_select 'ul.entity_templates > li', {
        count: DataCycleCore::Thing.where(template: true).where("schema ->> 'content_type' = 'entity'").count
      }
    end
  end
end
