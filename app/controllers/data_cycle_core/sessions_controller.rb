# frozen_string_literal: true

module DataCycleCore
  class SessionsController < Devise::SessionsController
    include DataCycleCore::ErrorHandler
    rescue_from ActionController::BadRequest, with: :bad_request
  end
end
