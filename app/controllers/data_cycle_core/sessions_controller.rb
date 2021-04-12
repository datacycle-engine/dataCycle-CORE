# frozen_string_literal: true

module DataCycleCore
  class SessionsController < Devise::SessionsController
    include DataCycleCore::ErrorHandler

    layout 'data_cycle_core/devise'
  end
end
