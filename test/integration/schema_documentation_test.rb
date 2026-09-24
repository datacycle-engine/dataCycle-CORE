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

      # the redesigned index renders one .schema-card per template, tagged with
      # its content_type; counts are derived from the same source the view groups
      # by (Schema.templates_with_content_type), so nothing is hard-coded
      assert_select '.schema-card[data-type="container"]', {
        count: DataCycleCore::Schema.templates_with_content_type('container').size
      }

      assert_select '.schema-card[data-type="entity"]', {
        count: DataCycleCore::Schema.templates_with_content_type('entity').size
      }
    end
  end
end
