# frozen_string_literal: true

module DataCycleCore
  module Oauth
    class UserinfoController < Doorkeeper::OpenidConnect::UserinfoController
      include DataCycleCore::ErrorHandler
    end
  end
end
