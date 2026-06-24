# frozen_string_literal: true

module DataCycleCore
  module Oauth
    class AuthorizedApplicationsController < Doorkeeper::AuthorizedApplicationsController
      include DataCycleCore::ErrorHandler

      layout 'data_cycle_core/application'
    end
  end
end
