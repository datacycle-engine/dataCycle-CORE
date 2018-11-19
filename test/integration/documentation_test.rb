# frozen_string_literal: true

require 'test_helper'

module DataCycleCore
  class DocumentationTest < ActionDispatch::IntegrationTest
    include Devise::Test::IntegrationHelpers
    include Engine.routes.url_helpers

    setup do
      @routes = Engine.routes
    end

    test 'docs path' do
      get '/docs/classifications'
      assert_response :success
    end

    test 'docs image path' do
      get '/docs/images/classification_mapping.svg'
      assert_response :success
    end
  end
end
