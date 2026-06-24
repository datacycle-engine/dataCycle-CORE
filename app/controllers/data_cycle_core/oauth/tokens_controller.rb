# frozen_string_literal: true

module DataCycleCore
  module Oauth
    class TokensController < Doorkeeper::TokensController
      include DataCycleCore::ErrorHandler
    end
  end
end
