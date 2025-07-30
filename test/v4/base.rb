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
    class Base < DataCycleCore::TestCases::ActionDispatchIntegrationTest
      include DataCycleCore::V4::ApiHelper

      # include DataCycleCore::V4::DummyDataHelper

      before(:all) do
        @routes = Engine.routes
        DataCycleCore::Thing.delete_all
      end

      setup do
        sign_in(User.find_by(email: 'tester@datacycle.at'))
      end
    end
  end
end
