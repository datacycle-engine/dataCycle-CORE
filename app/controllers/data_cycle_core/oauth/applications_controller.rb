# frozen_string_literal: true

module DataCycleCore
  module Oauth
    class ApplicationsController < Doorkeeper::ApplicationsController
      include DataCycleCore::ErrorHandler

      layout 'data_cycle_core/application'
    end
  end
end
