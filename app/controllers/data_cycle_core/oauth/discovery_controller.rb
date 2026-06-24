# frozen_string_literal: true

module DataCycleCore
  module Oauth
    class DiscoveryController < Doorkeeper::OpenidConnect::DiscoveryController
      include DataCycleCore::ErrorHandler
    end
  end
end
