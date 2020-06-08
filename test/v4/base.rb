# frozen_string_literal: true

require 'test_helper'
require 'json'
require 'v4/helpers/dummy_data_helper'
require 'v4/helpers/api_helper'
require 'v4/validation/context'
require 'v4/validation/concept'
require 'v4/validation/thing'

module DataCycleCore
  module V4
    class Base < ActionDispatch::IntegrationTest
      include Devise::Test::IntegrationHelpers
      include Engine.routes.url_helpers
      include DataCycleCore::V4::ApiHelper
      include DataCycleCore::V4::DummyDataHelper

      setup do
        @routes = Engine.routes
        sign_in(User.find_by(email: 'tester@datacycle.at'))
        DataCycleCore::Thing.where(template: false).delete_all
      end
    end
  end
end
