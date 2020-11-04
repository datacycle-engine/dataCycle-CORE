# frozen_string_literal: true

module DataCycleCore
  class SessionsController < Devise::SessionsController
    include DataCycleCore::ErrorHandler
  end
end
