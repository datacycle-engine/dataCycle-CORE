# frozen_string_literal: true

module DataCycleCore
  module Oauth
    class TokenInfoController < Doorkeeper::TokenInfoController
      include DataCycleCore::ErrorHandler
    end
  end
end
